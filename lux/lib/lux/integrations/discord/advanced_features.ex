defmodule Lux.Integrations.Discord.AdvancedFeatures do
  @moduledoc """
  Planning helpers for advanced Discord agent capabilities.

  These helpers build deterministic plans for voice channels, rich presence,
  webhooks, and server analytics. They do not open gateway connections or stream
  audio directly; a transport layer can execute the returned plans.
  """

  @activity_types %{
    playing: 0,
    streaming: 1,
    listening: 2,
    watching: 3,
    custom: 4,
    competing: 5
  }

  @voice_actions [:join, :leave, :play, :pause, :resume, :stop]
  @webhook_actions [:create, :update, :delete, :execute, :list]

  @doc "Builds a Discord voice-channel operation plan."
  def voice_channel_plan(attrs) when is_map(attrs) do
    action = attrs |> value(:action, :join) |> normalize_atom()

    with :ok <- ensure_known(action, @voice_actions, :unknown_voice_action),
         {:ok, guild_id} <- required(attrs, :guild_id),
         {:ok, channel_id} <- required_unless(attrs, :channel_id, action == :leave) do
      {:ok,
       %{
         action: action,
         guild_id: guild_id,
         channel_id: channel_id,
         gateway: voice_gateway_plan(action, attrs),
         audio: audio_plan(action, attrs),
         voice_activity_detection: vad_plan(attrs),
         queue: queue_plan(attrs),
         safety: %{
           requires_voice_state_update: action in [:join, :leave],
           requires_udp_voice_transport: action in [:join, :play, :resume],
           no_live_connection_opened: true
         }
       }}
    end
  end

  @doc "Builds a Discord rich-presence payload."
  def rich_presence_plan(attrs) when is_map(attrs) do
    activities =
      attrs
      |> value(:activities, [])
      |> List.wrap()
      |> Enum.map(&activity_payload/1)

    {:ok,
     %{
       op: 3,
       status: attrs |> value(:status, :online) |> to_string(),
       since: value(attrs, :since),
       afk: value(attrs, :afk, false),
       activities: activities,
       payload: %{
         "op" => 3,
         "d" => %{
           "since" => value(attrs, :since),
           "activities" => activities,
           "status" => attrs |> value(:status, :online) |> to_string(),
           "afk" => value(attrs, :afk, false)
         }
       }
     }}
  end

  @doc "Builds Discord webhook management or execution request plans."
  def webhook_plan(attrs) when is_map(attrs) do
    action = attrs |> value(:action, :execute) |> normalize_atom()

    with :ok <- ensure_known(action, @webhook_actions, :unknown_webhook_action),
         {:ok, request} <- webhook_request(action, attrs) do
      {:ok,
       %{
         action: action,
         request: request,
         retry_policy: %{
           attempts: value(attrs, :attempts, 3),
           backoff_ms: value(attrs, :backoff_ms, [250, 1_000, 5_000]),
           retry_on_status: [429, 500, 502, 503, 504]
         },
         event_trigger: value(attrs, :event_trigger)
       }}
    end
  end

  @doc "Summarizes Discord server activity, members, usage, and event logs."
  def analytics_report(events, attrs \\ %{}) when is_list(events) do
    normalized = Enum.map(events, &normalize_event/1)
    messages = Enum.filter(normalized, &(&1.type == :message))
    voice = Enum.filter(normalized, &(&1.type == :voice))
    webhooks = Enum.filter(normalized, &(&1.type == :webhook))
    members = attrs |> value(:members, []) |> Enum.map(&normalize_member/1)

    {:ok,
     %{
       guild_id: value(attrs, :guild_id),
       generated_at: value(attrs, :now),
       event_count: length(normalized),
       activity: %{
         messages: length(messages),
         voice_events: length(voice),
         webhook_events: length(webhooks),
         by_channel: count_by(normalized, :channel_id),
         by_hour: count_by_hour(normalized)
       },
       usage: %{
         active_users:
           normalized
           |> Enum.map(& &1.user_id)
           |> Enum.reject(&is_nil/1)
           |> Enum.uniq()
           |> length(),
         commands: Enum.count(normalized, &(&1.subtype == :command)),
         reactions: Enum.count(normalized, &(&1.subtype == :reaction)),
         audio_minutes: total_audio_minutes(normalized)
       },
       members: member_summary(members),
       event_log:
         Enum.map(normalized, &Map.take(&1, [:type, :subtype, :user_id, :channel_id, :timestamp]))
     }}
  end

  @doc "Builds a complete advanced Discord capability plan."
  def advanced_feature_plan(attrs) when is_map(attrs) do
    with {:ok, voice} <- voice_channel_plan(value(attrs, :voice, %{})),
         {:ok, presence} <- rich_presence_plan(value(attrs, :presence, %{})),
         {:ok, webhook} <- webhook_plan(value(attrs, :webhook, %{})),
         {:ok, analytics} <-
           analytics_report(value(attrs, :events, []), value(attrs, :analytics, %{})) do
      {:ok,
       %{
         voice: voice,
         rich_presence: presence,
         webhook: webhook,
         analytics: analytics,
         ready: true
       }}
    end
  end

  defp voice_gateway_plan(:join, attrs) do
    %{
      op: :voice_state_update,
      payload: %{
        guild_id: value(attrs, :guild_id),
        channel_id: value(attrs, :channel_id),
        self_mute: value(attrs, :self_mute, false),
        self_deaf: value(attrs, :self_deaf, false)
      },
      expected_events: [:voice_state_update, :voice_server_update]
    }
  end

  defp voice_gateway_plan(:leave, attrs) do
    %{
      op: :voice_state_update,
      payload: %{
        guild_id: value(attrs, :guild_id),
        channel_id: nil,
        self_mute: false,
        self_deaf: false
      },
      expected_events: [:voice_state_update]
    }
  end

  defp voice_gateway_plan(action, attrs) do
    %{
      op: :voice_playback_control,
      action: action,
      guild_id: value(attrs, :guild_id),
      channel_id: value(attrs, :channel_id)
    }
  end

  defp audio_plan(action, attrs) when action in [:play, :resume, :join] do
    %{
      codec: value(attrs, :codec, "opus"),
      sample_rate: value(attrs, :sample_rate, 48_000),
      channels: value(attrs, :channels, 2),
      frame_ms: value(attrs, :frame_ms, 20),
      source: value(attrs, :source),
      music_playback: %{
        enabled: action in [:play, :resume],
        loop: value(attrs, :loop, false),
        volume: value(attrs, :volume, 1.0)
      }
    }
  end

  defp audio_plan(_action, _attrs), do: %{music_playback: %{enabled: false}}

  defp vad_plan(attrs) do
    %{
      enabled: value(attrs, :vad_enabled, true),
      threshold: value(attrs, :vad_threshold, -45),
      silence_ms: value(attrs, :vad_silence_ms, 750),
      event: :voice_activity_detected
    }
  end

  defp queue_plan(attrs) do
    tracks = attrs |> value(:queue, []) |> List.wrap()

    %{
      tracks: Enum.map(tracks, &track/1),
      size: length(tracks),
      repeat: value(attrs, :repeat, false),
      shuffle: value(attrs, :shuffle, false)
    }
  end

  defp track(track) when is_map(track) do
    %{
      id: value(track, :id),
      title: value(track, :title),
      url: value(track, :url),
      duration_ms: value(track, :duration_ms)
    }
  end

  defp track(url), do: %{id: nil, title: nil, url: url, duration_ms: nil}

  defp activity_payload(activity) do
    kind = activity |> value(:type, :playing) |> normalize_atom()

    %{
      "name" => value(activity, :name, "Lux agent"),
      "type" => Map.get(@activity_types, kind, 0),
      "url" => value(activity, :url),
      "state" => value(activity, :state),
      "details" => value(activity, :details)
    }
    |> drop_nil_values()
  end

  defp webhook_request(:create, attrs) do
    with {:ok, channel_id} <- required(attrs, :channel_id) do
      {:ok,
       %{
         method: :post,
         path: "/channels/#{channel_id}/webhooks",
         json: %{
           name: value(attrs, :name, "Lux Webhook"),
           avatar: value(attrs, :avatar)
         }
       }}
    end
  end

  defp webhook_request(:update, attrs) do
    with {:ok, webhook_id} <- required(attrs, :webhook_id) do
      {:ok,
       %{
         method: :patch,
         path: "/webhooks/#{webhook_id}",
         json: %{
           name: value(attrs, :name),
           avatar: value(attrs, :avatar),
           channel_id: value(attrs, :channel_id)
         }
       }}
    end
  end

  defp webhook_request(:delete, attrs) do
    with {:ok, webhook_id} <- required(attrs, :webhook_id) do
      {:ok, %{method: :delete, path: "/webhooks/#{webhook_id}", json: %{}}}
    end
  end

  defp webhook_request(:execute, attrs) do
    with {:ok, webhook_id} <- required(attrs, :webhook_id),
         {:ok, token} <- required(attrs, :token) do
      {:ok,
       %{
         method: :post,
         path: "/webhooks/#{webhook_id}/#{token}",
         json:
           %{
             content: value(attrs, :content),
             username: value(attrs, :username),
             avatar_url: value(attrs, :avatar_url),
             embeds: value(attrs, :embeds, []),
             components: value(attrs, :components, [])
           }
           |> drop_nil_values()
       }}
    end
  end

  defp webhook_request(:list, attrs) do
    with {:ok, guild_id} <- required(attrs, :guild_id) do
      {:ok, %{method: :get, path: "/guilds/#{guild_id}/webhooks", json: %{}}}
    end
  end

  defp normalize_event(event) do
    %{
      type: event |> value(:type, :message) |> normalize_atom(),
      subtype: event |> value(:subtype) |> normalize_atom(),
      user_id: value(event, :user_id),
      channel_id: value(event, :channel_id),
      timestamp: value(event, :timestamp),
      duration_seconds: value(event, :duration_seconds, 0)
    }
  end

  defp normalize_member(member) do
    %{
      id: value(member, :id),
      bot: value(member, :bot, false),
      joined_at: value(member, :joined_at),
      roles: value(member, :roles, [])
    }
  end

  defp count_by(events, key) do
    events
    |> Enum.map(&Map.get(&1, key))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp count_by_hour(events) do
    events
    |> Enum.map(&hour_bucket/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp hour_bucket(%{timestamp: timestamp}) when is_binary(timestamp),
    do: String.slice(timestamp, 0, 13) <> ":00"

  defp hour_bucket(_event), do: nil

  defp total_audio_minutes(events) do
    events
    |> Enum.filter(&(&1.type == :voice))
    |> Enum.map(& &1.duration_seconds)
    |> Enum.sum()
    |> Kernel./(60)
  end

  defp member_summary(members) do
    bots = Enum.count(members, & &1.bot)

    %{
      total: length(members),
      bots: bots,
      humans: length(members) - bots,
      roles: members |> Enum.flat_map(& &1.roles) |> Enum.frequencies()
    }
  end

  defp required_unless(_map, _key, true), do: {:ok, nil}
  defp required_unless(map, key, false), do: required(map, key)

  defp required(map, key) do
    case value(map, key) do
      nil -> {:error, {:missing_required, key}}
      found -> {:ok, found}
    end
  end

  defp ensure_known(value, known, error), do: if(value in known, do: :ok, else: {:error, error})

  defp normalize_atom(nil), do: nil
  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value),
    do: value |> String.downcase() |> String.to_atom()

  defp normalize_atom(value), do: value

  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default
end
