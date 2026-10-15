defmodule Lux.Prisms.YouTube.CorePrism do
  @moduledoc """
  A Prism for YouTube Data API v3 and YouTube Live Streaming API operations, enabling
  Lux agents to authenticate via OAuth2, manage channel videos and playlists, schedule
  and transition live broadcasts, monitor stream health, and interact with live chat.

  Supported actions:
  - `"configure_oauth2"`: Configures OAuth2 credentials and issues an active token session
  - `"refresh_token"`: Refreshes the active OAuth2 access token
  - `"get_channel"`: Retrieves YouTube channel metadata and statistics
  - `"upload_video"`: Uploads a video with title, description, tags, and privacy status
  - `"update_video"`: Updates video metadata or privacy status
  - `"create_playlist"`: Creates a channel playlist
  - `"create_live_stream"`: Creates an RTMP/HLS ingestion stream with quality profile
  - `"create_live_broadcast"`: Schedules a live broadcast and initializes live chat
  - `"bind_broadcast"`: Binds an ingestion stream to a scheduled broadcast
  - `"transition_broadcast"`: Transitions broadcast (`testing`, `live`, `auto_live`, `complete`)
  - `"check_stream_health"`: Evaluates ingest telemetry and recommends quality adjustments
  - `"send_chat"`: Sends a message to a live broadcast chat room
  - `"poll_chat"`: Polls live chat messages with cursor pagination
  - `"moderate_chat"`: Deletes spam messages or times out / bans abusive users
  - `"get_quota_status"`: Inspects daily YouTube API quota usage and remaining units
  """

  use Lux.Prism,
    name: "YouTube Core & Live Streaming Prism",
    description:
      "Manages YouTube channels, video uploads, live broadcasts, stream telemetry, and live chat",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "YouTube operation to execute"
        },
        channel_id: %{
          type: :string,
          description: "YouTube Channel ID"
        },
        video_id: %{
          type: :string,
          description: "YouTube Video ID"
        },
        broadcast_id: %{
          type: :string,
          description: "YouTube LiveBroadcast ID"
        },
        stream_id: %{
          type: :string,
          description: "YouTube LiveStream ID"
        },
        live_chat_id: %{
          type: :string,
          description: "YouTube LiveChat ID"
        },
        title: %{
          type: :string,
          description: "Title for video, playlist, stream, or broadcast"
        },
        description: %{
          type: :string,
          description: "Description text"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy setting (public, unlisted, private)"
        },
        quality_profile: %{
          type: :string,
          description: "Stream quality profile (720p30, 1080p30, 1080p60, 1440p60, 4k60)"
        },
        target_state: %{
          type: :string,
          description: "Broadcast target state (testing, live, auto_live, complete)"
        },
        text: %{
          type: :string,
          description: "Live chat message text"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object}
      },
      required: ["status"]
    }

  alias Lux.Integrations.YouTube

  @doc """
  Executes the requested YouTube Core or Live Streaming action.
  """
  def handler(input, _ctx) do
    action = fetch_param(input, :action)
    dispatch(action, input)
  end

  defp dispatch("configure_oauth2", input) do
    case YouTube.configure_oauth2(input) do
      {:ok, session} -> {:ok, %{status: "ok", data: session}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("refresh_token", _input) do
    case YouTube.refresh_access_token() do
      {:ok, session} -> {:ok, %{status: "ok", data: session}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("get_channel", input) do
    channel_id = fetch_param(input, :channel_id, "UC_lux_default")

    case YouTube.get_channel(channel_id) do
      {:ok, channel} -> {:ok, %{status: "ok", data: channel}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("upload_video", input) do
    case YouTube.upload_video(input) do
      {:ok, video} -> {:ok, %{status: "ok", data: video}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("update_video", input) do
    video_id = fetch_param(input, :video_id, "")

    case YouTube.update_video(video_id, input) do
      {:ok, video} -> {:ok, %{status: "ok", data: video}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("create_playlist", input) do
    case YouTube.create_playlist(input) do
      {:ok, playlist} -> {:ok, %{status: "ok", data: playlist}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("create_live_stream", input) do
    case YouTube.create_live_stream(input) do
      {:ok, stream} -> {:ok, %{status: "ok", data: stream}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("create_live_broadcast", input) do
    case YouTube.create_live_broadcast(input) do
      {:ok, broadcast} -> {:ok, %{status: "ok", data: broadcast}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("bind_broadcast", input) do
    broadcast_id = fetch_param(input, :broadcast_id, "")
    stream_id = fetch_param(input, :stream_id, "")

    case YouTube.bind_broadcast_to_stream(broadcast_id, stream_id) do
      {:ok, broadcast} -> {:ok, %{status: "ok", data: broadcast}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("transition_broadcast", input) do
    broadcast_id = fetch_param(input, :broadcast_id, "")
    target_state = fetch_param(input, :target_state, "testing")

    case YouTube.transition_broadcast(broadcast_id, target_state) do
      {:ok, broadcast} -> {:ok, %{status: "ok", data: broadcast}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("check_stream_health", input) do
    stream_id = fetch_param(input, :stream_id, "")
    telemetry = fetch_param(input, :telemetry, %{})

    case YouTube.check_stream_health(stream_id, telemetry) do
      {:ok, health} -> {:ok, %{status: "ok", data: health}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("send_chat", input) do
    live_chat_id = fetch_param(input, :live_chat_id, "")
    text = fetch_param(input, :text, "")
    author = fetch_param(input, :author, "LuxStreamBot")

    case YouTube.send_chat_message(live_chat_id, text, author: author) do
      {:ok, msg} -> {:ok, %{status: "ok", data: msg}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("poll_chat", input) do
    live_chat_id = fetch_param(input, :live_chat_id, "")
    page_token = fetch_param(input, :page_token, 0)
    max_results = fetch_param(input, :max_results, 50)

    case YouTube.poll_chat_messages(live_chat_id,
           page_token: page_token,
           max_results: max_results
         ) do
      {:ok, page} -> {:ok, %{status: "ok", data: page}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("moderate_chat", input) do
    live_chat_id = fetch_param(input, :live_chat_id, "")
    mod_action = normalize_mod_action(fetch_param(input, :mod_action, :delete_message))

    case YouTube.moderate_chat(live_chat_id, mod_action, input) do
      {:ok, result} -> {:ok, %{status: "ok", data: result}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("get_quota_status", _input) do
    {:ok, status} = YouTube.get_quota_status()
    {:ok, %{status: "ok", data: status}}
  end

  defp dispatch(_unknown, _input), do: {:error, :unsupported_action}

  defp fetch_param(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp normalize_mod_action(a) when a in [:delete_message, "delete_message"], do: :delete_message
  defp normalize_mod_action(a) when a in [:timeout_user, "timeout_user"], do: :timeout_user
  defp normalize_mod_action(a) when a in [:ban_user, "ban_user"], do: :ban_user
  defp normalize_mod_action(_), do: :unknown
end
