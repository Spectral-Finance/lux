defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  HTTP client for YouTube OAuth, Data API v3, and resumable upload requests.

  Every API request accepts an explicit `:access_token` (or `"access_token"`) so
  agents can compose OAuth exchange/refresh results into downstream actions
  without relying on a single static application token.
  """

  @api_endpoint "https://www.googleapis.com/youtube/v3"
  @upload_endpoint "https://www.googleapis.com/upload/youtube/v3"
  @oauth_endpoint "https://oauth2.googleapis.com/token"

  @type request_opts :: map() | keyword()

  @doc """
  Exchanges an OAuth authorization code for access and refresh tokens.
  """
  @spec exchange_code(request_opts(), request_opts()) :: {:ok, map()} | {:error, term()}
  def exchange_code(params, opts \\ %{}) do
    with {:ok, form} <-
           required_form(params, [:client_id, :client_secret, :code, :redirect_uri]) do
      form
      |> Map.put("grant_type", "authorization_code")
      |> oauth_request(opts)
    end
  end

  @doc """
  Refreshes an OAuth access token with a refresh token.
  """
  @spec refresh_access_token(request_opts(), request_opts()) :: {:ok, map()} | {:error, term()}
  def refresh_access_token(params, opts \\ %{}) do
    with {:ok, form} <- required_form(params, [:client_id, :client_secret, :refresh_token]) do
      form
      |> Map.put("grant_type", "refresh_token")
      |> oauth_request(opts)
    end
  end

  @doc """
  Makes an authenticated YouTube Data API request and returns the decoded body.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    case request_raw(method, path, opts) do
      {:ok, response} -> {:ok, response.body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Makes an authenticated request and returns the full Req response.
  """
  @spec request_raw(atom(), String.t(), request_opts()) ::
          {:ok, Req.Response.t()} | {:error, term()}
  def request_raw(method, path, opts \\ %{}) do
    opts = to_map(opts)

    with {:ok, token} <- access_token(opts) do
      method
      |> request_options(path, opts, token)
      |> Req.new()
      |> Req.request()
      |> normalize_response()
    end
  end

  @doc """
  Starts a YouTube resumable video upload session.

  Returns the upload session URL from the `Location` response header. Uploading
  the bytes is deliberately a separate step so callers can persist/retry the
  session URL outside this request.
  """
  @spec start_resumable_upload(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def start_resumable_upload(metadata, opts \\ %{}) when is_map(metadata) do
    opts = to_map(opts)
    part = get(opts, :part, "snippet,status")
    headers = upload_headers(opts)

    request_opts =
      opts
      |> to_map()
      |> Map.put_new("base_url", @upload_endpoint)
      |> Map.put("params", %{
        "uploadType" => "resumable",
        "part" => part
      })
      |> Map.put("json", metadata)
      |> Map.update("headers", headers, &(headers ++ &1))

    case request_raw(:post, "/videos", request_opts) do
      {:ok, response} ->
        case response_header(response.headers, "location") do
          nil ->
            {:error, :missing_upload_location}

          session_url ->
            {:ok, %{session_url: session_url, body: response.body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Completes a resumable upload session with the video bytes.
  """
  @spec complete_resumable_upload(String.t(), binary(), request_opts()) ::
          {:ok, map() | list()} | {:error, term()}
  def complete_resumable_upload(session_url, bytes, opts \\ %{})
      when is_binary(session_url) and is_binary(bytes) do
    opts = to_map(opts)

    opts
    |> upload_session_options(:put, session_url, bytes)
    |> Req.new()
    |> Req.request()
    |> normalize_response()
    |> case do
      {:ok, response} -> {:ok, response.body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks a resumable upload session without sending additional video bytes.

  YouTube returns HTTP 308 while an upload is still in progress. The committed
  byte range is surfaced when present so agents can resume from the right offset.
  """
  @spec upload_status(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def upload_status(session_url, opts \\ %{}) when is_binary(session_url) do
    opts = to_map(opts)
    content_range = "bytes */#{get(opts, :total_size, "*")}"

    opts
    |> upload_session_options(:put, session_url, "", [{"Content-Range", content_range}])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: 308} = response} ->
        {:ok,
         %{
           status: :in_progress,
           committed_range: response_header(response.headers, "range")
         }}

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, %{status: :complete, body: body}}

      other ->
        normalize_response(other)
    end
  end

  def normalize_response({:ok, %{status: status} = response}) when status in 200..299,
    do: {:ok, response}

  def normalize_response({:ok, %{status: 401}}), do: {:error, :invalid_token}

  def normalize_response({:ok, %{status: status, body: body}}),
    do: {:error, normalize_error(status, body)}

  def normalize_response({:error, error}), do: {:error, error}

  def error_reason(%{"reason" => reason}), do: reason_to_atom(reason)
  def error_reason(_), do: :api_error

  def stringify_keys(value) when is_map(value) do
    Map.new(value, fn
      {key, val} when is_atom(key) -> {Atom.to_string(key), stringify_keys(val)}
      {key, val} -> {key, stringify_keys(val)}
    end)
  end

  def stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  def stringify_keys(value), do: value

  def get(map, key, default \\ nil)

  def get(map, key, default) when is_list(map) do
    map
    |> Map.new()
    |> get(key, default)
  end

  def get(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key)) || default
  end

  def get(map, key, default) when is_map(map) do
    Map.get(map, key) || default
  end

  defp oauth_request(form, opts) do
    opts = to_map(opts)

    [
      method: :post,
      url: @oauth_endpoint,
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      form: form
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(get(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
    |> case do
      {:ok, response} -> {:ok, response.body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_options(method, path, opts, token) do
    [
      method: method,
      url: get(opts, :base_url, @api_endpoint) <> path,
      headers: headers(opts, token),
      params: opts |> get(:params, %{}) |> stringify_keys(),
      json: opts |> get(:json) |> stringify_keys()
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(get(opts, :plug))
  end

  defp headers(opts, token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ] ++ get(opts, :headers, [])
  end

  defp upload_headers(opts) do
    [
      {"X-Upload-Content-Type", get(opts, :content_type, "video/*")}
    ]
    |> maybe_content_length(get(opts, :content_length))
  end

  defp upload_session_options(opts, method, session_url, body, extra_headers \\ []) do
    [
      method: method,
      url: session_url,
      headers: upload_session_headers(opts) ++ extra_headers,
      body: body
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(get(opts, :plug))
  end

  defp upload_session_headers(opts) do
    [{"Content-Type", get(opts, :content_type, "application/octet-stream")}]
    |> maybe_authorization(get(opts, :access_token) || get(opts, :token))
    |> Kernel.++(get(opts, :headers, []))
  end

  defp maybe_authorization(headers, token) when is_binary(token) and byte_size(token) > 0 do
    [{"Authorization", "Bearer #{token}"} | headers]
  end

  defp maybe_authorization(headers, _token), do: headers

  defp maybe_content_length(headers, nil), do: headers

  defp maybe_content_length(headers, length),
    do: [{"X-Upload-Content-Length", to_string(length)} | headers]

  defp access_token(opts) do
    token =
      get(opts, :access_token) ||
        get(opts, :token) ||
        configured_token()

    if is_binary(token) and token != "" do
      {:ok, token}
    else
      {:error, :missing_access_token}
    end
  end

  defp configured_token do
    Application.get_env(:lux, :api_keys, [])
    |> Keyword.get(:youtube)
  end

  defp required_form(params, fields) do
    params = to_map(params)

    form =
      Map.new(fields, fn field ->
        {Atom.to_string(field), get(params, field)}
      end)

    missing =
      form
      |> Enum.reject(fn {_key, value} -> is_binary(value) and value != "" end)
      |> Enum.map(fn {key, _value} -> key end)

    case missing do
      [] -> {:ok, form}
      _ -> {:error, {:missing_oauth_fields, missing}}
    end
  end

  defp normalize_error(status, %{"error" => %{"message" => message, "errors" => [first | _]}}) do
    {:youtube, error_reason(first), status, message}
  end

  defp normalize_error(status, %{"error" => %{"message" => message, "status" => reason}}) do
    {:youtube, reason_to_atom(reason), status, message}
  end

  defp normalize_error(status, %{"error" => %{"message" => message}}) do
    {:youtube, :api_error, status, message}
  end

  defp normalize_error(status, %{"error_description" => message}) do
    {:youtube, :oauth_error, status, message}
  end

  defp normalize_error(status, body), do: {:youtube, :api_error, status, body}

  defp reason_to_atom(reason) when is_binary(reason) do
    case Macro.underscore(reason) do
      "quota_exceeded" -> :quota_exceeded
      "daily_limit_exceeded" -> :quota_exceeded
      "rate_limit_exceeded" -> :rate_limited
      "user_rate_limit_exceeded" -> :rate_limited
      "forbidden" -> :permission_denied
      "insufficient_permissions" -> :permission_denied
      "not_found" -> :not_found
      "bad_request" -> :bad_request
      _ -> :api_error
    end
  end

  defp reason_to_atom(_), do: :api_error

  defp response_header(headers, wanted) when is_map(headers) do
    headers
    |> Map.get(String.downcase(wanted))
    |> header_value()
  end

  defp response_header(headers, wanted) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) == String.downcase(wanted), do: header_value(value)

      _ ->
        nil
    end)
  end

  defp header_value([value | _]), do: value
  defp header_value(value) when is_binary(value), do: value
  defp header_value(_), do: nil

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp to_map(value) when is_map(value), do: value
  defp to_map(value) when is_list(value), do: Map.new(value)
end
