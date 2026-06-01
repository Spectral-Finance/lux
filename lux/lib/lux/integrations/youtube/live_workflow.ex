defmodule Lux.Integrations.YouTube.LiveWorkflow do
  @moduledoc """
  Composable YouTube live-streaming workflow helpers.

  The transition helper enforces the safe YouTube live lifecycle:
  `ready -> testing -> live -> complete`.
  """

  alias Lux.Integrations.YouTube.Client

  @safe_transitions %{
    "ready" => ["testing"],
    "testing" => ["live"],
    "live" => ["complete"]
  }

  @doc """
  Creates a live broadcast.
  """
  def create_broadcast(attrs, opts \\ %{}) do
    body = %{
      snippet: %{
        title: required!(attrs, :title),
        scheduledStartTime: required!(attrs, :scheduled_start_time)
      },
      status: %{
        privacyStatus: Client.get(attrs, :privacy_status, "private")
      },
      contentDetails: %{
        enableAutoStart: Client.get(attrs, :enable_auto_start, false),
        enableAutoStop: Client.get(attrs, :enable_auto_stop, false)
      }
    }

    Client.request(
      :post,
      "/liveBroadcasts",
      attrs |> merge_opts(opts) |> put_request(body, "snippet,status,contentDetails")
    )
  end

  @doc """
  Creates a reusable live stream ingestion target.
  """
  def create_stream(attrs, opts \\ %{}) do
    body = %{
      snippet: %{title: required!(attrs, :title)},
      cdn: %{
        ingestionType: Client.get(attrs, :ingestion_type, "rtmp"),
        resolution: Client.get(attrs, :resolution, "1080p"),
        frameRate: Client.get(attrs, :frame_rate, "30fps")
      }
    }

    Client.request(
      :post,
      "/liveStreams",
      attrs |> merge_opts(opts) |> put_request(body, "snippet,cdn,status")
    )
  end

  @doc """
  Binds a broadcast to a stream.
  """
  def bind_broadcast(broadcast_id, stream_id, opts \\ %{}) do
    params = %{
      "part" => "id,contentDetails",
      "id" => broadcast_id,
      "streamId" => stream_id
    }

    Client.request(:post, "/liveBroadcasts/bind", Map.put(to_map(opts), "params", params))
  end

  @doc """
  Executes the setup part of a live stream: broadcast, stream, then binding.
  """
  def schedule(attrs, opts \\ %{}) do
    opts = merge_opts(attrs, opts)

    with {:ok, broadcast} <- create_broadcast(attrs, opts),
         {:ok, stream} <- create_stream(attrs, opts),
         {:ok, binding} <- bind_broadcast(broadcast["id"], stream["id"], opts) do
      {:ok, %{broadcast: broadcast, stream: stream, binding: binding}}
    end
  end

  @doc """
  Transitions a broadcast while enforcing YouTube's safe lifecycle.
  """
  def transition_broadcast(broadcast_id, current_status, target_status, opts \\ %{}) do
    current_status = to_string(current_status)
    target_status = to_string(target_status)

    if target_status in Map.get(@safe_transitions, current_status, []) do
      params = %{
        "part" => "id,status",
        "id" => broadcast_id,
        "broadcastStatus" => target_status
      }

      Client.request(:post, "/liveBroadcasts/transition", Map.put(to_map(opts), "params", params))
    else
      {:error, {:unsafe_transition, current_status, target_status}}
    end
  end

  @doc """
  Reads stream health for one live stream.
  """
  def stream_health(stream_id, opts \\ %{}) do
    params = %{"part" => "id,status", "id" => stream_id}

    case Client.request(:get, "/liveStreams", Map.put(to_map(opts), "params", params)) do
      {:ok, %{"items" => [stream | _]}} ->
        {:ok, normalize_stream_health(stream)}

      {:ok, %{"items" => []}} ->
        {:error, :stream_not_found}

      other ->
        other
    end
  end

  @doc """
  Lists live chat messages and returns pagination metadata.
  """
  def list_chat_messages(live_chat_id, opts \\ %{}) do
    opts = to_map(opts)

    params =
      %{
        "part" => "snippet,authorDetails",
        "liveChatId" => live_chat_id,
        "maxResults" => Client.get(opts, :max_results, 200)
      }
      |> maybe_put("pageToken", Client.get(opts, :page_token))

    case Client.request(:get, "/liveChat/messages", Map.put(opts, "params", params)) do
      {:ok, response} ->
        {:ok,
         %{
           items: response["items"] || [],
           next_page_token: response["nextPageToken"],
           polling_interval_ms: response["pollingIntervalMillis"]
         }}

      other ->
        other
    end
  end

  @doc """
  Polls live chat pages without sleeping, so agents can decide scheduling.
  """
  def poll_chat_messages(live_chat_id, opts \\ %{}) do
    do_poll(live_chat_id, to_map(opts), Client.get(opts, :max_pages, 3), [], nil)
  end

  @doc """
  Sends a text message to live chat.
  """
  def send_chat_message(live_chat_id, text, opts \\ %{}) do
    body = %{
      snippet: %{
        liveChatId: live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{messageText: text}
      }
    }

    Client.request(:post, "/liveChat/messages", put_request(opts, body, "snippet"))
  end

  defp do_poll(_live_chat_id, _opts, 0, items, page_token) do
    {:ok, %{items: Enum.reverse(items), next_page_token: page_token}}
  end

  defp do_poll(live_chat_id, opts, pages_left, items, page_token) do
    opts = maybe_put(opts, "page_token", page_token)

    case list_chat_messages(live_chat_id, opts) do
      {:ok, %{items: page_items, next_page_token: nil} = page} ->
        {:ok, %{page | items: Enum.reverse(page_items ++ items)}}

      {:ok, %{items: page_items, next_page_token: next_page_token}} ->
        do_poll(live_chat_id, opts, pages_left - 1, page_items ++ items, next_page_token)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_request(opts, body, part) do
    opts
    |> to_map()
    |> Map.put("params", %{"part" => part})
    |> Map.put("json", body)
  end

  defp normalize_stream_health(stream) do
    health = get_in(stream, ["status", "healthStatus"]) || %{}

    %{
      id: stream["id"],
      stream_status: get_in(stream, ["status", "streamStatus"]),
      health_status: health["status"],
      configuration_issues: health["configurationIssues"] || []
    }
  end

  defp required!(attrs, key) do
    case Client.get(attrs, key) do
      nil -> raise ArgumentError, "missing required #{key}"
      value -> value
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp merge_opts(attrs, opts), do: Map.merge(to_map(attrs), to_map(opts))

  defp to_map(value) when is_map(value), do: value
  defp to_map(value) when is_list(value), do: Map.new(value)
end
