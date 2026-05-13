defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  HTTP client and endpoint helpers for the YouTube Data API v3.

  The client is intentionally small and mockable: callers pass an OAuth2 access
  token or configure `YOUTUBE_ACCESS_TOKEN`, and tests can inject a `Req.Test`
  plug through application config or request options.
  """

  @api_endpoint "https://www.googleapis.com/youtube/v3"
  @upload_endpoint "https://www.googleapis.com/upload/youtube/v3"

  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:query) => keyword() | map(),
          optional(:body) => iodata(),
          optional(:plug) => {module(), term()}
        }

  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    method
    |> build_request(@api_endpoint <> path, opts)
    |> Req.new()
    |> Req.request()
    |> parse_response()
  end

  @spec token_request(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def token_request(form, opts \\ %{}) do
    [
      method: :post,
      url: Lux.Integrations.YouTube.token_endpoint(),
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
      body: URI.encode_query(form),
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> parse_response()
  end

  @spec exchange_authorization_code(keyword()) :: {:ok, map()} | {:error, term()}
  def exchange_authorization_code(opts) do
    token_request(
      %{
        code: Keyword.fetch!(opts, :code),
        client_id: Keyword.fetch!(opts, :client_id),
        client_secret: Keyword.fetch!(opts, :client_secret),
        redirect_uri: Keyword.fetch!(opts, :redirect_uri),
        grant_type: "authorization_code"
      },
      Map.new(opts)
    )
  end

  @spec refresh_access_token(keyword()) :: {:ok, map()} | {:error, term()}
  def refresh_access_token(opts) do
    token_request(
      %{
        refresh_token: Keyword.fetch!(opts, :refresh_token),
        client_id: Keyword.fetch!(opts, :client_id),
        client_secret: Keyword.fetch!(opts, :client_secret),
        grant_type: "refresh_token"
      },
      Map.new(opts)
    )
  end

  @spec list_channels(request_opts()) :: {:ok, map()} | {:error, term()}
  def list_channels(opts \\ %{}) do
    request(
      :get,
      "/channels",
      put_query(opts, part: "snippet,contentDetails,statistics", mine: true)
    )
  end

  @spec initiate_resumable_upload(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def initiate_resumable_upload(metadata, opts \\ %{}) do
    :post
    |> build_request(
      @upload_endpoint <> "/videos",
      opts
      |> put_query(part: "snippet,status", uploadType: "resumable")
      |> Map.put(:json, metadata)
    )
    |> Req.new()
    |> Req.request()
    |> parse_response()
  end

  @spec insert_live_broadcast(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def insert_live_broadcast(broadcast, opts \\ %{}) do
    request(
      :post,
      "/liveBroadcasts",
      opts |> put_query(part: "snippet,status,contentDetails") |> Map.put(:json, broadcast)
    )
  end

  @spec insert_live_stream(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def insert_live_stream(stream, opts \\ %{}) do
    request(
      :post,
      "/liveStreams",
      opts |> put_query(part: "snippet,cdn,status") |> Map.put(:json, stream)
    )
  end

  @spec bind_live_broadcast(String.t(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def bind_live_broadcast(broadcast_id, stream_id, opts \\ %{}) do
    request(
      :post,
      "/liveBroadcasts/bind",
      put_query(opts,
        id: broadcast_id,
        streamId: stream_id,
        part: "id,snippet,contentDetails,status"
      )
    )
  end

  @spec transition_live_broadcast(String.t(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def transition_live_broadcast(broadcast_id, status, opts \\ %{}) do
    request(
      :post,
      "/liveBroadcasts/transition",
      put_query(opts, id: broadcast_id, broadcastStatus: status, part: "id,snippet,status")
    )
  end

  @spec list_live_chat_messages(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def list_live_chat_messages(live_chat_id, opts \\ %{}) do
    request(
      :get,
      "/liveChat/messages",
      put_query(opts, liveChatId: live_chat_id, part: "id,snippet,authorDetails")
    )
  end

  @spec insert_live_chat_message(String.t(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def insert_live_chat_message(live_chat_id, text, opts \\ %{}) do
    body = %{
      snippet: %{
        liveChatId: live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{messageText: text}
      }
    }

    request(
      :post,
      "/liveChat/messages",
      opts |> put_query(part: "snippet") |> Map.put(:json, body)
    )
  end

  @spec list_stream_health(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def list_stream_health(stream_id, opts \\ %{}) do
    request(:get, "/liveStreams", put_query(opts, id: stream_id, part: "id,status,cdn"))
  end

  defp build_request(method, url, opts) do
    token = opts[:token] || Lux.Config.youtube_access_token()

    [
      method: method,
      url: request_url(url, opts[:query]),
      headers:
        [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}] ++
          (opts[:headers] || []),
      json: opts[:json],
      body: opts[:body],
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
  end

  defp request_url(url, nil), do: url
  defp request_url(url, query), do: url <> "?" <> URI.encode_query(query)

  defp put_query(opts, query) do
    Map.put(opts, :query, Keyword.merge(Keyword.new(opts[:query] || []), query))
  end

  defp parse_response({:ok, %{status: status, body: body} = response}) when status in 200..299 do
    location = get_header(response, "location")

    if location do
      {:ok, %{"location" => location, "body" => body || %{}}}
    else
      {:ok, body || %{}}
    end
  end

  defp parse_response({:ok, %{status: 401}}), do: {:error, :invalid_token}

  defp parse_response(
         {:ok, %{status: status, body: %{"error" => %{"message" => message, "errors" => errors}}}}
       )
       when status in [403, 429] do
    {:error, {:rate_limited, message, errors}}
  end

  defp parse_response({:ok, %{status: status, body: %{"error" => %{"message" => message}}}}) do
    {:error, {status, message}}
  end

  defp parse_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp parse_response({:error, error}), do: {:error, error}

  defp get_header(response, name) do
    response.headers
    |> Map.get(name, [])
    |> List.first()
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
