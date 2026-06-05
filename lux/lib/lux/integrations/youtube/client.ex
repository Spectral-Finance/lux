defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  Request helpers for YouTube Data API v3 and OAuth token flows.

  The module keeps request construction explicit so tests and agents can validate
  Data API calls without requiring live YouTube credentials.
  """

  @api_endpoint "https://www.googleapis.com/youtube/v3"
  @upload_endpoint "https://www.googleapis.com/upload/youtube/v3"
  @oauth_authorize_endpoint "https://accounts.google.com/o/oauth2/v2/auth"
  @oauth_token_endpoint "https://oauth2.googleapis.com/token"

  @default_scopes [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl"
  ]

  @type request_opts :: %{
          optional(:access_token) => String.t(),
          optional(:query) => map(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()},
          optional(:base_url) => String.t()
        }

  @doc """
  Builds the OAuth 2.0 authorization URL for YouTube channel access.
  """
  @spec authorization_url(map()) :: String.t()
  def authorization_url(opts) do
    query =
      %{
        client_id: fetch!(opts, :client_id),
        redirect_uri: fetch!(opts, :redirect_uri),
        response_type: "code",
        access_type: get(opts, :access_type, "offline"),
        prompt: get(opts, :prompt, "consent"),
        scope: get(opts, :scopes, @default_scopes) |> Enum.join(" "),
        state: get(opts, :state, nil)
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> URI.encode_query()

    @oauth_authorize_endpoint <> "?" <> query
  end

  @doc """
  Builds an OAuth token request for authorization-code or refresh-token exchange.
  """
  @spec token_request(:authorization_code | :refresh_token, map()) :: map()
  def token_request(:authorization_code, opts) do
    %{
      method: :post,
      url: @oauth_token_endpoint,
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      form: %{
        client_id: fetch!(opts, :client_id),
        client_secret: fetch!(opts, :client_secret),
        code: fetch!(opts, :code),
        grant_type: "authorization_code",
        redirect_uri: fetch!(opts, :redirect_uri)
      }
    }
  end

  def token_request(:refresh_token, opts) do
    %{
      method: :post,
      url: @oauth_token_endpoint,
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      form: %{
        client_id: fetch!(opts, :client_id),
        client_secret: fetch!(opts, :client_secret),
        grant_type: "refresh_token",
        refresh_token: fetch!(opts, :refresh_token)
      }
    }
  end

  @doc """
  Builds a YouTube Data API request map without executing it.
  """
  @spec build_request(atom(), String.t(), request_opts()) :: map()
  def build_request(method, path, opts \\ %{}) do
    access_token = get(opts, :access_token, nil)
    base_url = get(opts, :base_url, @api_endpoint)
    query = get(opts, :query, %{}) |> normalize_query()
    json = get(opts, :json, nil)

    %{
      method: method,
      url: base_url <> path,
      query: query,
      headers: build_headers(access_token, get(opts, :headers, [])),
      json: json
    }
  end

  @doc """
  Executes a YouTube Data API request.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    method
    |> build_request(path, opts)
    |> Map.to_list()
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(get(opts, :plug, nil))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
  end

  @doc """
  Builds the initial resumable upload request for videos.insert.
  """
  @spec resumable_upload_request(map()) :: map()
  def resumable_upload_request(opts) do
    metadata =
      %{
        snippet: %{
          title: fetch!(opts, :title),
          description: get(opts, :description, ""),
          tags: get(opts, :tags, []),
          categoryId: get(opts, :category_id, "22")
        },
        status: %{
          privacyStatus: get(opts, :privacy_status, "private"),
          selfDeclaredMadeForKids: get(opts, :made_for_kids, false)
        }
      }

    build_request(:post, "/videos", %{
      access_token: get(opts, :access_token, nil),
      base_url: @upload_endpoint,
      query: %{uploadType: "resumable", part: "snippet,status"},
      headers: [
        {"X-Upload-Content-Type", get(opts, :content_type, "video/mp4")},
        {"X-Upload-Content-Length", to_string(get(opts, :content_length, 0))}
      ],
      json: metadata
    })
  end

  @doc """
  Builds a chunk upload request for an established resumable upload session.

  The upload URL must be the `Location` response header returned by the initial
  resumable videos.insert request.
  """
  @spec resumable_chunk_request(map()) :: map()
  def resumable_chunk_request(opts) do
    upload_url = fetch!(opts, :upload_url)
    content_length = fetch_integer!(opts, :content_length)
    range_start = get_integer(opts, :range_start, 0)
    range_end = get_integer(opts, :range_end, range_start + content_length - 1)
    total_length = get_integer(opts, :total_length, content_length)

    %{
      method: :put,
      url: upload_url,
      query: %{},
      headers:
        upload_session_headers(get(opts, :access_token, nil), [
          {"Content-Type", get(opts, :content_type, "video/mp4")},
          {"Content-Length", to_string(content_length)},
          {"Content-Range", "bytes #{range_start}-#{range_end}/#{total_length}"}
        ]),
      body: get(opts, :body, :video_binary)
    }
  end

  @doc """
  Builds a status probe request for resuming an interrupted upload session.
  """
  @spec resumable_resume_request(map()) :: map()
  def resumable_resume_request(opts) do
    upload_url = fetch!(opts, :upload_url)
    total_length = fetch_integer!(opts, :total_length)

    %{
      method: :put,
      url: upload_url,
      query: %{},
      headers:
        upload_session_headers(get(opts, :access_token, nil), [
          {"Content-Length", "0"},
          {"Content-Range", "bytes */#{total_length}"}
        ]),
      body: ""
    }
  end

  @doc """
  Returns the default OAuth scopes needed for channel, upload, live, and chat APIs.
  """
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  defp normalize_response({:ok, %{status: status} = response}) when status in 200..299 do
    {:ok, response.body || %{}}
  end

  defp normalize_response({:ok, %{status: 401}}), do: {:error, :invalid_token}

  defp normalize_response({:ok, %{status: 403, body: %{"error" => error}}}) do
    {:error, {:forbidden, extract_error_message(error)}}
  end

  defp normalize_response({:ok, %{status: 429, body: body}}), do: {:error, {:rate_limited, body}}

  defp normalize_response({:ok, %{status: status, body: %{"error" => error}}}) do
    {:error, {status, extract_error_message(error)}}
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp extract_error_message(%{"message" => message}), do: message
  defp extract_error_message(%{message: message}), do: message
  defp extract_error_message(error), do: error

  defp build_headers(nil, headers), do: [{"Content-Type", "application/json"} | headers]

  defp build_headers(access_token, headers) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
      | headers
    ]
  end

  defp upload_session_headers(nil, headers), do: headers

  defp upload_session_headers(access_token, headers) do
    [{"Authorization", "Bearer #{access_token}"} | headers]
  end

  defp normalize_query(query) do
    query
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new(fn {key, value} -> {camelize_key(key), normalize_query_value(value)} end)
  end

  defp normalize_query_value(value) when is_list(value), do: Enum.join(value, ",")
  defp normalize_query_value(value), do: value

  defp camelize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> camelize_key()
  end

  defp camelize_key(key) when is_binary(key) do
    [first | rest] = String.split(key, "_")

    Enum.join([first | Enum.map(rest, &String.capitalize/1)], "")
  end

  defp get(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp fetch!(map, key) do
    case get(map, key, nil) do
      nil -> raise ArgumentError, "missing required YouTube option #{key}"
      "" -> raise ArgumentError, "missing required YouTube option #{key}"
      value -> value
    end
  end

  defp fetch_integer!(map, key) do
    case integer(fetch!(map, key)) do
      nil -> raise ArgumentError, "invalid YouTube option #{key}"
      value -> value
    end
  end

  defp get_integer(map, key, default) do
    case integer(get(map, key, default)) do
      nil -> default
      value -> value
    end
  end

  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: trunc(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      {number, rest} -> if String.trim(rest) == "", do: number, else: nil
      _ -> nil
    end
  end

  defp integer(_value), do: nil

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
