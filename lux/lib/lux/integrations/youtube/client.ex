defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  Req-based YouTube Data API v3 and Live Streaming API client.
  """

  alias Lux.Integrations.YouTube

  @type request_opts :: keyword() | map()

  @doc "Makes a raw YouTube API request."
  @spec request(atom(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def request(method, path, opts \\ []) do
    settings = YouTube.client_settings()
    base_url = option(opts, :base_url, settings.api_base_url)
    params = opts |> option(:params, %{}) |> with_api_key(option(opts, :api_key))
    headers = settings.headers ++ auth_headers(opts) ++ option(opts, :headers, [])

    [
      method: method,
      url: base_url <> path,
      headers: headers,
      params: params,
      json: option(opts, :json)
    ]
    |> maybe_add_plug(option(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
  end

  @doc "Lists channels for the authenticated user."
  @spec channels_mine(request_opts()) :: {:ok, map()} | {:error, term()}
  def channels_mine(opts \\ []) do
    request(
      :get,
      "/channels",
      merge_params(opts, %{part: "id,snippet,contentDetails,statistics", mine: true})
    )
  end

  @doc "Lists videos by id, chart, or other YouTube-supported filters."
  @spec videos_list(request_opts()) :: {:ok, map()} | {:error, term()}
  def videos_list(opts \\ []) do
    request(
      :get,
      "/videos",
      merge_params(opts, %{part: "id,snippet,status,contentDetails,liveStreamingDetails"})
    )
  end

  @doc "Starts a resumable video upload by sending metadata to videos.insert."
  @spec videos_insert(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def videos_insert(video, opts \\ []) do
    settings = YouTube.client_settings()

    request(
      :post,
      "/videos",
      opts
      |> put_option(:base_url, settings.upload_base_url)
      |> merge_params(%{
        part: option(opts, :part, "snippet,status"),
        uploadType: option(opts, :upload_type, "resumable")
      })
      |> put_option(:json, video)
    )
  end

  @doc "Updates video metadata."
  @spec videos_update(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def videos_update(video, opts \\ []) do
    request(
      :put,
      "/videos",
      opts
      |> merge_params(%{part: option(opts, :part, "snippet,status")})
      |> put_option(:json, video)
    )
  end

  @doc "Deletes a video by id."
  @spec videos_delete(String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def videos_delete(video_id, opts \\ []) do
    request(:delete, "/videos", merge_params(opts, %{id: video_id}))
  end

  @doc "Lists live broadcasts."
  @spec live_broadcasts_list(request_opts()) :: {:ok, map()} | {:error, term()}
  def live_broadcasts_list(opts \\ []) do
    request(
      :get,
      "/liveBroadcasts",
      merge_params(opts, %{part: "id,snippet,contentDetails,status"})
    )
  end

  @doc "Creates a live broadcast."
  @spec live_broadcasts_insert(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def live_broadcasts_insert(broadcast, opts \\ []) do
    request(
      :post,
      "/liveBroadcasts",
      opts
      |> merge_params(%{part: option(opts, :part, "snippet,contentDetails,status")})
      |> put_option(:json, broadcast)
    )
  end

  @doc "Updates a live broadcast."
  @spec live_broadcasts_update(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def live_broadcasts_update(broadcast, opts \\ []) do
    request(
      :put,
      "/liveBroadcasts",
      opts
      |> merge_params(%{part: option(opts, :part, "snippet,contentDetails,status")})
      |> put_option(:json, broadcast)
    )
  end

  @doc "Binds a live broadcast to a live stream."
  @spec live_broadcasts_bind(String.t(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def live_broadcasts_bind(broadcast_id, stream_id, opts \\ []) do
    request(
      :post,
      "/liveBroadcasts/bind",
      merge_params(opts, %{
        id: broadcast_id,
        streamId: stream_id,
        part: option(opts, :part, "id,snippet,contentDetails,status")
      })
    )
  end

  @doc "Transitions a live broadcast to testing, live, or complete."
  @spec live_broadcasts_transition(String.t(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def live_broadcasts_transition(broadcast_id, status, opts \\ []) do
    request(
      :post,
      "/liveBroadcasts/transition",
      merge_params(opts, %{
        id: broadcast_id,
        broadcastStatus: status,
        part: option(opts, :part, "id,snippet,contentDetails,status")
      })
    )
  end

  @doc "Lists live streams."
  @spec live_streams_list(request_opts()) :: {:ok, map()} | {:error, term()}
  def live_streams_list(opts \\ []) do
    request(:get, "/liveStreams", merge_params(opts, %{part: "id,snippet,cdn,status"}))
  end

  @doc "Creates a live stream ingestion resource."
  @spec live_streams_insert(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def live_streams_insert(stream, opts \\ []) do
    request(
      :post,
      "/liveStreams",
      opts
      |> merge_params(%{part: option(opts, :part, "snippet,cdn,status")})
      |> put_option(:json, stream)
    )
  end

  @doc "Lists live chat messages."
  @spec live_chat_messages_list(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def live_chat_messages_list(live_chat_id, opts \\ []) do
    request(
      :get,
      "/liveChat/messages",
      merge_params(opts, %{
        liveChatId: live_chat_id,
        part: option(opts, :part, "id,snippet,authorDetails")
      })
    )
  end

  @doc "Sends a text message to a live chat."
  @spec live_chat_messages_insert(String.t(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def live_chat_messages_insert(live_chat_id, message_text, opts \\ []) do
    body = %{
      snippet: %{
        liveChatId: live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{messageText: message_text}
      }
    }

    request(
      :post,
      "/liveChat/messages",
      opts |> merge_params(%{part: "snippet"}) |> put_option(:json, body)
    )
  end

  defp normalize_response({:ok, %{status: status, body: body, headers: headers}})
       when status in 200..299 do
    {:ok, maybe_add_upload_url(body, headers)}
  end

  defp normalize_response({:ok, %{status: status, body: %{"error" => %{"message" => message}}}}) do
    {:error, {status, message}}
  end

  defp normalize_response({:ok, %{status: status, body: %{"error" => error}}}) do
    {:error, {status, error}}
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp maybe_add_upload_url(body, headers) do
    case header_value(headers, "location") do
      location when is_binary(location) and location != "" -> add_upload_url(body, location)
      _location -> body
    end
  end

  defp add_upload_url(body, location) when is_map(body),
    do: Map.put_new(body, "upload_url", location)

  defp add_upload_url(body, location) when body in ["", nil], do: %{"upload_url" => location}
  defp add_upload_url(body, location), do: %{"body" => body, "upload_url" => location}

  defp header_value(headers, name) when is_map(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: first_header(value)
    end)
  end

  defp header_value(headers, name) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: first_header(value)

      _header ->
        nil
    end)
  end

  defp header_value(_headers, _name), do: nil

  defp first_header([value | _values]), do: value
  defp first_header(value), do: value

  defp auth_headers(opts) do
    case option(opts, :access_token) do
      token when is_binary(token) and token != "" -> [{"authorization", "Bearer #{token}"}]
      _token -> []
    end
  end

  defp with_api_key(params, nil), do: params
  defp with_api_key(params, ""), do: params
  defp with_api_key(params, api_key), do: Map.put(opts_map(params), :key, api_key)

  defp merge_params(opts, defaults) do
    params = opts |> option(:params, %{}) |> opts_map()
    put_option(opts, :params, Map.merge(defaults, params))
  end

  defp put_option(opts, key, value) when is_map(opts), do: Map.put(opts, key, value)
  defp put_option(opts, key, value) when is_list(opts), do: Keyword.put(opts, key, value)

  defp option(opts, key, default \\ nil)
  defp option(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
