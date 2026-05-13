defmodule Lux.Integrations.YouTube.LiveStreaming do
  @moduledoc """
  Planning and monitoring helpers for YouTube live broadcasts, streams, and chat.
  """

  @default_policy %{
    minimum_health: :good,
    allowed_resolutions: ["720p", "1080p", "1440p", "2160p"],
    allowed_frame_rates: ["30fps", "60fps"],
    require_active_stream_for_live: true,
    default_privacy_status: "private"
  }

  @doc "Builds a liveBroadcasts.insert request body."
  @spec broadcast_body(map(), keyword() | map()) :: map()
  def broadcast_body(params, opts \\ []) do
    policy = policy(opts)

    %{
      snippet: %{
        title: value(params, :title),
        description: value(params, :description, ""),
        scheduledStartTime: value(params, :scheduled_start_time),
        scheduledEndTime: value(params, :scheduled_end_time)
      },
      status: %{
        privacyStatus: value(params, :privacy_status, policy.default_privacy_status),
        selfDeclaredMadeForKids: value(params, :made_for_kids, false)
      },
      contentDetails: %{
        enableAutoStart: value(params, :enable_auto_start, false),
        enableAutoStop: value(params, :enable_auto_stop, false),
        enableDvr: value(params, :enable_dvr, true),
        recordFromStart: value(params, :record_from_start, true),
        monitorStream: %{
          enableMonitorStream: value(params, :enable_monitor_stream, true)
        }
      }
    }
  end

  @doc "Builds a liveStreams.insert request body."
  @spec stream_body(map()) :: map()
  def stream_body(params) do
    %{
      snippet: %{
        title: value(params, :title),
        description: value(params, :description, "")
      },
      cdn: %{
        ingestionType: value(params, :ingestion_type, "rtmp"),
        resolution: value(params, :resolution, "1080p"),
        frameRate: value(params, :frame_rate, "30fps")
      }
    }
  end

  @doc "Builds a live chat text-message request body."
  @spec chat_message_body(String.t(), String.t()) :: map()
  def chat_message_body(live_chat_id, message_text) do
    %{
      snippet: %{
        liveChatId: live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{messageText: message_text}
      }
    }
  end

  @doc "Summarizes broadcast and stream status for health monitoring."
  @spec stream_health(map(), map()) :: map()
  def stream_health(broadcast, stream) do
    broadcast_status = value(broadcast, [:status, :lifeCycleStatus])
    stream_status = value(stream, [:status, :streamStatus])
    health_status = value(stream, [:status, :healthStatus, :status], "unknown")
    issues = value(stream, [:status, :healthStatus, :configurationIssues], [])

    %{
      broadcast_id: value(broadcast, :id),
      stream_id: value(stream, :id),
      broadcast_status: broadcast_status,
      stream_status: stream_status,
      health_status: health_status,
      issues: issues,
      ready_for_testing: broadcast_status in ["ready", "testing"] and stream_status == "active",
      ready_for_live:
        broadcast_status in ["ready", "testing"] and stream_status == "active" and
          health_status in ["good", "ok"]
    }
  end

  @doc "Checks whether a broadcast can transition to the requested status."
  @spec transition_plan(map(), map(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, map()}
  def transition_plan(broadcast, stream, target_status, opts \\ []) do
    policy = policy(opts)
    health = stream_health(broadcast, stream)

    alerts =
      []
      |> maybe_add(
        target_status not in ["testing", "live", "complete"],
        "unsupported transition target"
      )
      |> maybe_add(
        target_status in ["testing", "live"] and policy.require_active_stream_for_live and
          health.stream_status != "active",
        "stream must be active before testing or live transition"
      )
      |> maybe_add(
        target_status == "live" and not health.ready_for_live,
        "stream health is not ready for live"
      )

    plan = %{
      broadcast_id: health.broadcast_id,
      stream_id: health.stream_id,
      target_status: target_status,
      current_broadcast_status: health.broadcast_status,
      stream_status: health.stream_status,
      health_status: health.health_status,
      alerts: Enum.reverse(alerts)
    }

    if plan.alerts == [] do
      {:ok, Map.put(plan, :decision, :approved)}
    else
      {:error, Map.put(plan, :decision, :blocked)}
    end
  end

  @doc "Evaluates stream CDN settings for multi-stream quality control."
  @spec quality_control([map()], keyword() | map()) :: map()
  def quality_control(streams, opts \\ []) when is_list(streams) do
    policy = policy(opts)

    checked =
      Enum.map(streams, fn stream ->
        cdn = value(stream, :cdn, %{})
        resolution = value(cdn, :resolution)
        frame_rate = value(cdn, :frameRate)

        alerts =
          []
          |> maybe_add(resolution not in policy.allowed_resolutions, "unsupported resolution")
          |> maybe_add(frame_rate not in policy.allowed_frame_rates, "unsupported frame rate")

        %{
          stream_id: value(stream, :id),
          title: value(stream, [:snippet, :title]),
          resolution: resolution,
          frame_rate: frame_rate,
          status: if(alerts == [], do: :ready, else: :attention_required),
          alerts: Enum.reverse(alerts)
        }
      end)

    %{
      status:
        if(Enum.any?(checked, &(&1.status == :attention_required)),
          do: :attention_required,
          else: :ready
        ),
      streams: checked
    }
  end

  @doc "Normalizes live chat messages for monitoring workflows."
  @spec chat_messages(map()) :: [map()]
  def chat_messages(payload) do
    payload
    |> value(:items, [])
    |> Enum.map(fn item ->
      %{
        id: value(item, :id),
        author: value(item, [:authorDetails, :displayName]),
        message: value(item, [:snippet, :displayMessage]),
        type: value(item, [:snippet, :type]),
        published_at: value(item, [:snippet, :publishedAt])
      }
    end)
  end

  @doc "Builds a compact live control dashboard."
  @spec dashboard(map(), keyword() | map()) :: map()
  def dashboard(input, opts \\ []) do
    broadcast = value(input, :broadcast, %{})
    stream = value(input, :stream, %{})

    %{
      health: stream_health(broadcast, stream),
      quality: quality_control(value(input, :streams, [stream]), opts),
      chat: chat_messages(value(input, :chat_messages, %{}))
    }
  end

  defp policy(opts), do: Map.merge(@default_policy, opts |> value(:policy, %{}) |> opts_map())

  defp maybe_add(alerts, true, message), do: [message | alerts]
  defp maybe_add(alerts, false, _message), do: alerts

  defp value(data, path, default \\ nil)
  defp value(data, [key | rest], default), do: data |> value(key, %{}) |> value(rest, default)
  defp value(data, [], _default), do: data
  defp value(map, key, default) when is_map(map), do: map_get(map, key, default)
  defp value(list, key, default) when is_list(list), do: Keyword.get(list, key, default)
  defp value(_other, _key, default), do: default

  defp map_get(map, key, default) do
    string_key = to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, string_key) -> Map.fetch!(map, string_key)
      true -> default
    end
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)
end
