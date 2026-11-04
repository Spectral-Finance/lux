defmodule Lux.Beams.Discord.AdvancedDiscordPipelineBeam do
  @moduledoc """
  A Beam pipeline coordinating advanced Discord features:
  1. Synchronizes bot Rich Presence and gaming activity (`RichPresencePrism`).
  2. Establishes voice channel connectivity and prepares streaming (`VoicePrism`).
  3. Records session telemetry in server analytics (`AnalyticsPrism`).
  4. Triggers operational notifications via Discord webhooks (`WebhookPrism`).

  ## Example Usage

  ```elixir
  {:ok, result} = Lux.Beams.Discord.AdvancedDiscordPipelineBeam.run(%{
    guild_id: "123456789012345678",
    channel_id: "234567890123456789",
    activity_name: "Autonomous Trading Agent",
    webhook_url: "https://discord.com/api/webhooks/mock/token"
  })
  ```
  """

  use Lux.Beam,
    name: "Advanced Discord Pipeline Beam",
    description: "Orchestrates Rich Presence, voice connections, telemetry analytics, and webhook dispatch",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord Guild ID"},
        channel_id: %{type: :string, description: "Voice Channel ID"},
        activity_name: %{type: :string, description: "Game or presence title"},
        webhook_url: %{type: :string, description: "Target webhook URL"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        status: %{type: :string}
      },
      required: ["guild_id", "status"]
    }

  alias Lux.Prisms.Discord.Advanced.AnalyticsPrism
  alias Lux.Prisms.Discord.Advanced.RichPresencePrism
  alias Lux.Prisms.Discord.Advanced.VoicePrism
  alias Lux.Prisms.Discord.Advanced.WebhookPrism

  sequence do
    step(:sync_presence, RichPresencePrism, %{
      action: "sync_game",
      activity_name: [:input, :activity_name]
    })

    step(:join_voice, VoicePrism, %{
      action: "connect",
      guild_id: [:input, :guild_id],
      channel_id: [:input, :channel_id]
    })

    step(:log_telemetry, AnalyticsPrism, %{
      action: "log_event",
      guild_id: [:input, :guild_id],
      event_type: "agent_session_started"
    })

    step(:notify_webhook, WebhookPrism, %{
      action: "trigger_event",
      webhook_url: [:input, :webhook_url],
      event_name: "AGENT_VOICE_SESSION_ACTIVE"
    })
  end
end
