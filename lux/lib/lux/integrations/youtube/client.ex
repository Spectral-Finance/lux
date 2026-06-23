defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  Basic HTTP client for YouTube Data API v3 requests.
  """

  require Logger

  @endpoint "https://www.googleapis.com/youtube/v3"

  @type request_opts :: %{
    optional(:api_key) => String.t(),
    optional(:access_token) => String.t(),
    optional(:json) => map(),
    optional(:params) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the YouTube Data API v3.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/videos", "/search")
    * `opts` - Request options (see Options section)

  ## Options

    * `:api_key` - YouTube Data API key (for public data access)
    * `:access_token` - OAuth2 access token (for authenticated actions)
    * `:json` - Request body for POST/PUT requests
    * `:params` - Query parameters
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Using an API key for read operations
      iex> YouTube.Client.request(:get, "/videos", %{
      ...>   api_key: "your_api_key",
      ...>   params: %{part: "snippet", id: "dQw4w9WgXcQ"}
      ...> })
      {:ok, %{"items" => [...]}}

      # Using an OAuth2 token for write operations
      iex> YouTube.Client.request(:post, "/liveBroadcasts", %{
      ...>   access_token: "your_oauth_token",
      ...>   params: %{part: "snippet,status"},
      ...>   json: %{snippet: %{title: "My Stream"}}
      ...> })
      {:ok, %{"id" => "abc123"}}

  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | Req.Response.t()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    dry_run = Map.get(opts, :dry_run) || Application.get_env(:lux, :youtube_dry_run, false) || System.get_env("YOUTUBE_DRY_RUN") == "true"

    if dry_run and method in [:post, :put, :delete] do
      mock_body = mock_response(method, path, opts)
      if opts[:return_response] do
        {:ok, %Req.Response{status: 200, headers: [{"content-type", "application/json"}], body: mock_body}}
      else
        {:ok, mock_body}
      end
    else
      api_key = opts[:api_key] || Lux.Config.youtube_api_key()
      access_token = opts[:access_token]

      headers = build_headers(access_token) ++ (opts[:headers] || [])
      params = Map.merge(opts[:params] || %{}, if(access_token, do: %{}, else: %{key: api_key}))

      url = if String.starts_with?(path, "http"), do: path, else: @endpoint <> path

      [
        method: method,
        url: url,
        headers: headers,
        params: params,
        json: opts[:json]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])
      |> Req.new()
      |> Req.request()
      |> case do
        {:ok, %{status: status} = response} when status in 200..299 or status == 308 ->
          if opts[:return_response] do
            {:ok, response}
          else
            {:ok, response.body}
          end

        {:ok, %{status: 401}} ->
          {:error, :invalid_token}

        {:ok, %{status: 403, body: %{"error" => %{"message" => message}}}} ->
          {:error, {403, message}}

        {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
          {:error, {status, message}}

        {:ok, %{status: status, body: body}} ->
          {:error, {status, body}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp build_headers(nil), do: [{"Content-Type", "application/json"}]
  defp build_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp mock_response(_method, path, opts) do
    cond do
      String.contains?(path, "/playlists") ->
        title = get_in(opts, [:json, :snippet, :title]) || "Mock Playlist"
        privacy_status = get_in(opts, [:json, :status, :privacyStatus]) || "private"
        %{"id" => "mock_playlist_id", "snippet" => %{"title" => title}, "status" => %{"privacyStatus" => privacy_status}}

      String.contains?(path, "/videos") ->
        if String.contains?(path, "upload") || String.contains?(opts[:params][:uploadType] || "", "resumable") do
          %{"id" => "mock_uploaded_video_id"}
        else
          video_id = get_in(opts, [:json, :id]) || "mock_video_id"
          title = get_in(opts, [:json, :snippet, :title]) || "Mock Video"
          %{"id" => video_id, "snippet" => %{"title" => title}}
        end

      String.contains?(path, "/liveBroadcasts/bind") ->
        %{"id" => "mock_broadcast_id"}

      String.contains?(path, "/liveBroadcasts/transition") ->
        status = opts[:params][:broadcastStatus] || "testing"
        %{"id" => opts[:params][:id] || "mock_broadcast_id", "status" => %{"lifeCycleStatus" => status}}

      String.contains?(path, "/liveBroadcasts") ->
        title = get_in(opts, [:json, :snippet, :title]) || "Mock Broadcast"
        privacy_status = get_in(opts, [:json, :status, :privacyStatus]) || "private"
        %{"id" => "mock_broadcast_id", "snippet" => %{"title" => title}, "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => privacy_status}}

      String.contains?(path, "/liveStreams") ->
        _title = get_in(opts, [:json, :snippet, :title]) || "Mock Stream"
        %{"id" => "mock_stream_id", "cdn" => %{"ingestionInfo" => %{"ingestionAddress" => "rtmp://mock.youtube.com/live2", "streamName" => "mock_stream_key"}}}

      String.contains?(path, "/liveChat/messages") ->
        text = get_in(opts, [:json, :snippet, :textMessageDetails, :messageText]) || "Mock Message"
        %{"id" => "mock_message_id", "snippet" => %{"textMessageDetails" => %{"messageText" => text}}}

      true ->
        %{"status" => "success", "mocked" => true}
    end
  end
end

