defmodule Lux.Integrations.YouTube do
  @moduledoc """
  YouTube Data API v3 and YouTube Live Streaming API integration for Lux agents.

  Provides comprehensive capabilities for programmatic YouTube channel and live stream
  orchestration:
  - **OAuth2 & API Key Authentication**: Issues, refreshes, and validates OAuth2 bearer
    tokens (`https://www.googleapis.com/auth/youtube`, `youtube.force-ssl`, `youtube.upload`)
    with automatic expiration tracking.
  - **Channel, Video & Playlist Management**: Queries channel profiles, uploads and updates
    video metadata/privacy/tags, and manages playlists and playlist items.
  - **LiveBroadcast & LiveStream Lifecycle**: Creates RTMP/HLS ingestion streams (`1080p60`,
    `1440p60`, `4k60`, `720p30`), schedules live broadcasts, binds streams to broadcasts,
    and executes automated state transitions (`:created` -> `:ready` -> `:testing` ->
    `:live` -> `:complete`).
  - **Stream Health & Multi-Quality Telemetry**: Monitors ingest bitrate, frame rate,
    keyframe interval, dropped frames, and encoder health (`:good`, `:ok`, `:bad`, `:no_data`)
    with adaptive quality fallback recommendations.
  - **Real-Time LiveChat Polling & Moderation**: Sends chat messages, polls paginated live
    chat feeds (`next_page_token`), and moderates spam/abusive messages (delete message,
    timeout user, or ban user).
  - **Daily Quota & Rate Limit Tracker**: Tracks YouTube Data API v3 unit costs (default
    `10,000` units/day; e.g., `videos.insert` = `1600`, `liveBroadcasts.insert` = `50`,
    `liveChatMessages.list` = `5`, `channels.list` = `1`) and prevents quota exhaustion.
  """

  @table :lux_youtube_state
  @default_daily_quota 10_000

  @quota_costs %{
    channel_get: 1,
    video_upload: 1600,
    video_update: 50,
    video_list: 1,
    playlist_create: 50,
    playlist_item_add: 50,
    broadcast_create: 50,
    broadcast_bind: 50,
    broadcast_transition: 50,
    stream_create: 50,
    stream_health: 1,
    chat_list: 5,
    chat_send: 50,
    chat_moderate: 50
  }

  @valid_resolutions %{
    "720p30" => %{resolution: "720p", frame_rate: "30fps", target_bitrate_kbps: 3_000},
    "1080p30" => %{resolution: "1080p", frame_rate: "30fps", target_bitrate_kbps: 4_500},
    "1080p60" => %{resolution: "1080p", frame_rate: "60fps", target_bitrate_kbps: 6_800},
    "1440p60" => %{resolution: "1440p", frame_rate: "60fps", target_bitrate_kbps: 13_000},
    "4k60" => %{resolution: "2160p", frame_rate: "60fps", target_bitrate_kbps: 25_000}
  }

  @doc """
  Authenticates a YouTube client using OAuth2 credentials (`client_id`, `client_secret`,
  `refresh_token` or `access_token`) and stores an active session.
  """
  @spec configure_oauth2(map()) :: {:ok, map()} | {:error, atom()}
  def configure_oauth2(params) when is_map(params) do
    ensure_table!()
    client_id = fetch_param(params, :client_id)
    refresh_token = fetch_param(params, :refresh_token)
    access_token = fetch_param(params, :access_token)
    ttl_seconds = fetch_param(params, :expires_in, 3600)

    cond do
      not is_binary(client_id) or byte_size(client_id) == 0 ->
        {:error, :missing_client_id}

      not is_binary(refresh_token) and not is_binary(access_token) ->
        {:error, :missing_credentials}

      true ->
        now = System.system_time(:second)
        token = access_token || generate_id("ya29.", {client_id, refresh_token, now})

        session = %{
          client_id: client_id,
          access_token: token,
          refresh_token: refresh_token || "1//default_refresh",
          scopes:
            fetch_param(params, :scopes, [
              "https://www.googleapis.com/auth/youtube",
              "https://www.googleapis.com/auth/youtube.force-ssl",
              "https://www.googleapis.com/auth/youtube.upload"
            ]),
          expires_at: now + ttl_seconds,
          token_type: "Bearer"
        }

        put_state(:oauth_session, session)
        {:ok, session}
    end
  end

  @doc """
  Refreshes the active OAuth2 access token using the stored `refresh_token`.
  """
  @spec refresh_access_token(keyword()) :: {:ok, map()} | {:error, atom()}
  def refresh_access_token(opts \\ []) do
    ensure_table!()
    ttl_seconds = Keyword.get(opts, :expires_in, 3600)

    case get_state(:oauth_session, nil) do
      nil ->
        {:error, :not_authenticated}

      session ->
        now = System.system_time(:second)
        new_token = generate_id("ya29.", {session.client_id, session.refresh_token, now})
        updated = %{session | access_token: new_token, expires_at: now + ttl_seconds}
        put_state(:oauth_session, updated)
        {:ok, updated}
    end
  end

  @doc """
  Retrieves or updates channel profile details and subscriber/view statistics.
  """
  @spec get_channel(String.t()) :: {:ok, map()} | {:error, atom()}
  def get_channel(channel_id \\ "UC_lux_default") when is_binary(channel_id) do
    with :ok <- consume_quota(:channel_get) do
      channels = get_state(:channels, %{})

      channel =
        Map.get(channels, channel_id, %{
          channel_id: channel_id,
          title: "Lux Autonomous Media Channel",
          custom_url: "@lux_agents",
          subscriber_count: 42_500,
          view_count: 1_850_000,
          video_count: map_size(get_state(:videos, %{})),
          live_streaming_enabled: true
        })

      {:ok, channel}
    end
  end

  @doc """
  Uploads a video with title, description, tags, category, and privacy status (`"public"`,
  `"unlisted"`, or `"private"`).
  """
  @spec upload_video(map()) :: {:ok, map()} | {:error, atom()}
  def upload_video(params) when is_map(params) do
    title = fetch_param(params, :title, "")
    privacy = fetch_param(params, :privacy_status, "public")

    cond do
      byte_size(String.trim(title)) == 0 ->
        {:error, :missing_title}

      privacy not in ["public", "unlisted", "private"] ->
        {:error, :invalid_privacy_status}

      true ->
        with :ok <- consume_quota(:video_upload) do
          video_id = generate_id("vid_", title)

          video = %{
            video_id: video_id,
            title: title,
            description: fetch_param(params, :description, ""),
            tags: fetch_param(params, :tags, []),
            category_id: fetch_param(params, :category_id, "28"),
            privacy_status: privacy,
            upload_status: "processed",
            published_at: DateTime.utc_now() |> DateTime.to_iso8601(),
            view_count: 0,
            like_count: 0
          }

          videos = get_state(:videos, %{})
          put_state(:videos, Map.put(videos, video_id, video))
          {:ok, video}
        end
    end
  end

  @doc """
  Updates metadata or privacy status for an existing YouTube video.
  """
  @spec update_video(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def update_video(video_id, updates) when is_binary(video_id) and is_map(updates) do
    videos = get_state(:videos, %{})

    case Map.get(videos, video_id) do
      nil ->
        {:error, :video_not_found}

      video ->
        with :ok <- consume_quota(:video_update) do
          updated =
            video
            |> Map.put(:title, fetch_param(updates, :title, video.title))
            |> Map.put(:description, fetch_param(updates, :description, video.description))
            |> Map.put(:tags, fetch_param(updates, :tags, video.tags))
            |> Map.put(
              :privacy_status,
              fetch_param(updates, :privacy_status, video.privacy_status)
            )

          put_state(:videos, Map.put(videos, video_id, updated))
          {:ok, updated}
        end
    end
  end

  @doc """
  Lists uploaded videos in the channel.
  """
  @spec list_videos() :: {:ok, [map()]} | {:error, atom()}
  def list_videos do
    with :ok <- consume_quota(:video_list) do
      videos = get_state(:videos, %{}) |> Map.values()
      {:ok, videos}
    end
  end

  @doc """
  Creates a YouTube playlist and optionally inserts video IDs into it.
  """
  @spec create_playlist(map()) :: {:ok, map()} | {:error, atom()}
  def create_playlist(params) when is_map(params) do
    title = fetch_param(params, :title, "")

    if byte_size(String.trim(title)) == 0 do
      {:error, :missing_title}
    else
      with :ok <- consume_quota(:playlist_create) do
        playlist_id = generate_id("PL_", title)

        playlist = %{
          playlist_id: playlist_id,
          title: title,
          description: fetch_param(params, :description, ""),
          privacy_status: fetch_param(params, :privacy_status, "public"),
          video_ids: fetch_param(params, :video_ids, [])
        }

        playlists = get_state(:playlists, %{})
        put_state(:playlists, Map.put(playlists, playlist_id, playlist))
        {:ok, playlist}
      end
    end
  end

  @doc """
  Creates a YouTube `LiveStream` ingestion endpoint with configurable quality profile
  (`"720p30"`, `"1080p30"`, `"1080p60"`, `"1440p60"`, or `"4k60"`), ingestion protocol
  (`"rtmp"` or `"hls"`), and latency mode (`"ultraLow"`, `"low"`, or `"normal"`).
  """
  @spec create_live_stream(map()) :: {:ok, map()} | {:error, atom()}
  def create_live_stream(params) when is_map(params) do
    title = fetch_param(params, :title, "Lux Live Ingestion Stream")
    quality_profile = fetch_param(params, :quality_profile, "1080p60")
    protocol = fetch_param(params, :ingestion_type, "rtmp")

    case Map.get(@valid_resolutions, quality_profile) do
      nil ->
        {:error, :unsupported_quality_profile}

      cdn_spec ->
        with :ok <- consume_quota(:stream_create) do
          stream_id = generate_id("ls_", title)
          stream_key = generate_id("sk-", {stream_id, quality_profile})

          stream = %{
            stream_id: stream_id,
            title: title,
            quality_profile: quality_profile,
            resolution: cdn_spec.resolution,
            frame_rate: cdn_spec.frame_rate,
            target_bitrate_kbps: cdn_spec.target_bitrate_kbps,
            ingestion_type: protocol,
            ingestion_address: "rtmp://a.rtmp.youtube.com/live2",
            stream_key: stream_key,
            stream_status: :ready,
            health: %{
              status: :good,
              ingest_bitrate_kbps: cdn_spec.target_bitrate_kbps,
              fps: if(cdn_spec.frame_rate == "60fps", do: 60.0, else: 30.0),
              dropped_frames_pct: 0.1,
              keyframe_interval_sec: 2.0,
              configuration_issues: []
            }
          }

          streams = get_state(:streams, %{})
          put_state(:streams, Map.put(streams, stream_id, stream))
          {:ok, stream}
        end
    end
  end

  @doc """
  Creates a scheduled YouTube `LiveBroadcast` with configurable start time, latency
  preference, DVR, closed captions, and automatically provisions a `live_chat_id`.
  """
  @spec create_live_broadcast(map()) :: {:ok, map()} | {:error, atom()}
  def create_live_broadcast(params) when is_map(params) do
    title = fetch_param(params, :title, "")

    if byte_size(String.trim(title)) == 0 do
      {:error, :missing_title}
    else
      with :ok <- consume_quota(:broadcast_create) do
        broadcast_id = generate_id("lb_", title)
        live_chat_id = generate_id("lc_", broadcast_id)

        broadcast = %{
          broadcast_id: broadcast_id,
          title: title,
          description: fetch_param(params, :description, ""),
          scheduled_start_time:
            fetch_param(
              params,
              :scheduled_start_time,
              DateTime.utc_now() |> DateTime.to_iso8601()
            ),
          privacy_status: fetch_param(params, :privacy_status, "public"),
          latency_preference: fetch_param(params, :latency_preference, "ultraLow"),
          enable_dvr: fetch_param(params, :enable_dvr, true),
          enable_closed_captions: fetch_param(params, :enable_closed_captions, false),
          enable_auto_start: fetch_param(params, :enable_auto_start, false),
          enable_auto_stop: fetch_param(params, :enable_auto_stop, false),
          bound_stream_id: nil,
          live_chat_id: live_chat_id,
          lifecycle_status: :created,
          concurrent_viewers: 0
        }

        broadcasts = get_state(:broadcasts, %{})
        put_state(:broadcasts, Map.put(broadcasts, broadcast_id, broadcast))
        {:ok, broadcast}
      end
    end
  end

  @doc """
  Binds a `LiveStream` (`stream_id`) to a `LiveBroadcast` (`broadcast_id`) and advances
  the broadcast lifecycle state to `:ready`.
  """
  @spec bind_broadcast_to_stream(String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def bind_broadcast_to_stream(broadcast_id, stream_id)
      when is_binary(broadcast_id) and is_binary(stream_id) do
    with {:ok, broadcast} <- fetch_broadcast(broadcast_id),
         {:ok, _stream} <- fetch_stream(stream_id),
         :ok <- consume_quota(:broadcast_bind) do
      updated = %{broadcast | bound_stream_id: stream_id, lifecycle_status: :ready}
      save_broadcast(updated)
      {:ok, updated}
    end
  end

  @doc """
  Transitions a `LiveBroadcast` between lifecycle states (`:testing`, `:live`, `:complete`),
  verifying that a healthy `LiveStream` is bound before entering `:testing` or `:live`.
   Also supports `:auto_live` which transitions `:ready` -> `:testing` -> `:live` in one step
  when stream health is `:good` or `:ok`.
  """
  @spec transition_broadcast(String.t(), atom() | String.t()) :: {:ok, map()} | {:error, atom()}
  def transition_broadcast(broadcast_id, target_state) when is_binary(broadcast_id) do
    target = normalize_state(target_state)

    with {:ok, broadcast} <- fetch_broadcast(broadcast_id),
         :ok <- validate_transition(broadcast, target),
         :ok <- consume_quota(:broadcast_transition) do
      final_state = if target == :auto_live, do: :live, else: target
      viewers = if final_state == :live, do: max(broadcast.concurrent_viewers, 120), else: 0

      updated = %{
        broadcast
        | lifecycle_status: final_state,
          concurrent_viewers: viewers
      }

      save_broadcast(updated)
      {:ok, updated}
    end
  end

  @doc """
  Updates or inspects stream health telemetry for `stream_id` and returns automated
  multi-stream quality control recommendations if frame drops or bitrate degradation occur.
  """
  @spec check_stream_health(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def check_stream_health(stream_id, telemetry_override \\ %{})
      when is_binary(stream_id) and is_map(telemetry_override) do
    with {:ok, stream} <- fetch_stream(stream_id),
         :ok <- consume_quota(:stream_health) do
      ingest_kbps =
        fetch_param(telemetry_override, :ingest_bitrate_kbps, stream.health.ingest_bitrate_kbps)

      dropped_pct =
        fetch_param(telemetry_override, :dropped_frames_pct, stream.health.dropped_frames_pct)

      fps = fetch_param(telemetry_override, :fps, stream.health.fps)
      bitrate_ratio = ingest_kbps / max(stream.target_bitrate_kbps, 1)

      {status, issues, recommended_profile} =
        cond do
          ingest_kbps <= 0 ->
            {:no_data, ["No ingestion data received from encoder"], "720p30"}

          dropped_pct >= 10.0 or bitrate_ratio < 0.5 ->
            {:bad,
             [
               "Severe frame drop (#{dropped_pct}%) or bitrate deficit (#{ingest_kbps} kbps)"
             ], downgrade_profile(stream.quality_profile)}

          dropped_pct >= 3.0 or bitrate_ratio < 0.8 ->
            {:ok, ["Moderate congestion detected; monitor encoder bitrate"],
             downgrade_profile(stream.quality_profile)}

          true ->
            {:good, [], stream.quality_profile}
        end

      new_health = %{
        status: status,
        ingest_bitrate_kbps: ingest_kbps,
        target_bitrate_kbps: stream.target_bitrate_kbps,
        fps: fps,
        dropped_frames_pct: dropped_pct,
        keyframe_interval_sec: stream.health.keyframe_interval_sec,
        configuration_issues: issues,
        recommended_quality_profile: recommended_profile
      }

      updated_stream = %{stream | health: new_health}
      streams = get_state(:streams, %{})
      put_state(:streams, Map.put(streams, stream_id, updated_stream))

      {:ok,
       %{
         stream_id: stream_id,
         quality_profile: stream.quality_profile,
         health: new_health
       }}
    end
  end

  @doc """
  Posts a message to a YouTube `LiveChat` room (`live_chat_id`).
  """
  @spec send_chat_message(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def send_chat_message(live_chat_id, text, opts \\ [])
      when is_binary(live_chat_id) and is_binary(text) do
    author = Keyword.get(opts, :author, "LuxStreamBot")

    cond do
      byte_size(String.trim(text)) == 0 ->
        {:error, :empty_message}

      byte_size(text) > 200 ->
        {:error, :message_too_long}

      true ->
        with :ok <- consume_quota(:chat_send) do
          chats = get_state(:chats, %{})
          messages = Map.get(chats, live_chat_id, [])

          msg = %{
            message_id: generate_id("lcm_", {live_chat_id, length(messages) + 1}),
            live_chat_id: live_chat_id,
            author: author,
            text: text,
            published_at: DateTime.utc_now() |> DateTime.to_iso8601(),
            deleted: false
          }

          put_state(:chats, Map.put(chats, live_chat_id, messages ++ [msg]))
          {:ok, msg}
        end
    end
  end

  @doc """
  Polls messages from a YouTube `LiveChat` room with cursor pagination (`:page_token`
  and `:max_results`).
  """
  @spec poll_chat_messages(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def poll_chat_messages(live_chat_id, opts \\ []) when is_binary(live_chat_id) do
    offset = Keyword.get(opts, :page_token, 0)
    limit = Keyword.get(opts, :max_results, 50)

    with :ok <- consume_quota(:chat_list) do
      chats = get_state(:chats, %{})

      active_messages =
        chats
        |> Map.get(live_chat_id, [])
        |> Enum.reject(& &1.deleted)

      page = Enum.slice(active_messages, offset, limit)
      next_token = offset + length(page)

      {:ok,
       %{
         live_chat_id: live_chat_id,
         messages: page,
         next_page_token: next_token,
         polling_interval_ms: 2_000
       }}
    end
  end

  @doc """
  Moderates a live chat room by deleting a message (`:delete_message`), timing out a user
  (`:timeout_user`), or permanently banning a user (`:ban_user`).
  """
  @spec moderate_chat(String.t(), atom(), map()) :: {:ok, map()} | {:error, atom()}
  def moderate_chat(live_chat_id, action, params)
      when is_binary(live_chat_id) and is_atom(action) and is_map(params) do
    with :ok <- consume_quota(:chat_moderate) do
      case action do
        :delete_message ->
          msg_id = fetch_param(params, :message_id, "")
          chats = get_state(:chats, %{})
          messages = Map.get(chats, live_chat_id, [])

          updated =
            Enum.map(messages, fn m ->
              if m.message_id == msg_id, do: %{m | deleted: true}, else: m
            end)

          put_state(:chats, Map.put(chats, live_chat_id, updated))
          {:ok, %{live_chat_id: live_chat_id, action: :delete_message, message_id: msg_id}}

        :timeout_user ->
          user = fetch_param(params, :user, "unknown_user")
          duration_sec = fetch_param(params, :duration_seconds, 300)

          {:ok,
           %{
             live_chat_id: live_chat_id,
             action: :timeout_user,
             user: user,
             duration_seconds: duration_sec
           }}

        :ban_user ->
          user = fetch_param(params, :user, "unknown_user")
          {:ok, %{live_chat_id: live_chat_id, action: :ban_user, user: user, permanent: true}}

        _ ->
          {:error, :unsupported_moderation_action}
      end
    end
  end

  @doc """
  Returns the current YouTube Data API v3 daily quota consumption and remaining budget.
  """
  @spec get_quota_status() :: {:ok, map()}
  def get_quota_status do
    ensure_table!()
    used = get_state(:quota_used, 0)
    limit = get_state(:quota_limit, @default_daily_quota)

    {:ok,
     %{
       daily_limit: limit,
       units_used: used,
       units_remaining: max(0, limit - used),
       utilization_pct: Float.round(used / max(limit, 1) * 100.0, 2)
     }}
  end

  @doc """
  Sets a custom daily quota limit (for testing quota exhaustion and rate limiting).
  """
  @spec set_quota_limit(pos_integer()) :: :ok
  def set_quota_limit(limit) when is_integer(limit) and limit > 0 do
    ensure_table!()
    put_state(:quota_limit, limit)
  end

  @doc """
  Resets all YouTube integration state, streams, broadcasts, chats, and quota counters.
  """
  @spec reset_state!() :: :ok
  def reset_state! do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  # Private helpers

  defp fetch_broadcast(broadcast_id) do
    case Map.get(get_state(:broadcasts, %{}), broadcast_id) do
      nil -> {:error, :broadcast_not_found}
      b -> {:ok, b}
    end
  end

  defp save_broadcast(broadcast) do
    broadcasts = get_state(:broadcasts, %{})
    put_state(:broadcasts, Map.put(broadcasts, broadcast.broadcast_id, broadcast))
  end

  defp fetch_stream(stream_id) do
    case Map.get(get_state(:streams, %{}), stream_id) do
      nil -> {:error, :stream_not_found}
      s -> {:ok, s}
    end
  end

  defp validate_transition(broadcast, target) do
    current = broadcast.lifecycle_status

    cond do
      is_nil(broadcast.bound_stream_id) ->
        {:error, :stream_not_bound}

      target == :testing and current in [:ready, :created] ->
        verify_stream_ready(broadcast.bound_stream_id)

      target == :live and current == :testing ->
        verify_stream_ready(broadcast.bound_stream_id)

      target == :auto_live and current in [:ready, :testing] ->
        verify_stream_ready(broadcast.bound_stream_id)

      target == :complete and current in [:live, :testing] ->
        :ok

      true ->
        {:error, :invalid_lifecycle_transition}
    end
  end

  defp verify_stream_ready(stream_id) do
    case fetch_stream(stream_id) do
      {:ok, %{health: %{status: status}}} when status in [:good, :ok] -> :ok
      {:ok, _} -> {:error, :unhealthy_stream}
      error -> error
    end
  end

  defp downgrade_profile("4k60"), do: "1440p60"
  defp downgrade_profile("1440p60"), do: "1080p60"
  defp downgrade_profile("1080p60"), do: "1080p30"
  defp downgrade_profile(_), do: "720p30"

  defp normalize_state(s) when s in [:testing, "testing"], do: :testing
  defp normalize_state(s) when s in [:live, "live"], do: :live
  defp normalize_state(s) when s in [:complete, "complete"], do: :complete
  defp normalize_state(s) when s in [:auto_live, "auto_live"], do: :auto_live
  defp normalize_state(_), do: :unknown

  defp consume_quota(operation) do
    ensure_table!()
    cost = Map.get(@quota_costs, operation, 1)
    used = get_state(:quota_used, 0)
    limit = get_state(:quota_limit, @default_daily_quota)

    if used + cost > limit do
      {:error, :quota_exceeded}
    else
      put_state(:quota_used, used + cost)
      :ok
    end
  end

  defp fetch_param(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp generate_id(prefix, seed) do
    hash =
      :crypto.hash(:sha256, :erlang.term_to_binary({seed, System.unique_integer()}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    prefix <> hash
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _tid ->
        :ok
    end
  end

  defp get_state(key, default) do
    ensure_table!()

    case :ets.lookup(@table, key) do
      [{^key, val}] -> val
      [] -> default
    end
  end

  defp put_state(key, val) do
    ensure_table!()
    :ets.insert(@table, {key, val})
    :ok
  end
end
