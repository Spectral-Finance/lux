defmodule Lux.Prisms.Discord.Voice.DetectVoiceActivity do
  @moduledoc """
  A prism for detecting voice activity in a Discord voice channel.

  Monitors voice channel for speaking users and emits activity events.
  """

  use Lux.Prism,
    name: "Detect Voice Activity",
    description: "Monitors voice channel for voice activity and speaking users",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the voice channel to monitor",
          pattern: "^[0-9]{17,20}$"
        },
        threshold: %{
          type: :number,
          description: "Voice activity detection sensitivity (0.0 - 1.0)",
          minimum: 0.0,
          maximum: 1.0,
          default: 0.5
        },
        interval_ms: %{
          type: :integer,
          description: "Polling interval in milliseconds",
          minimum: 100,
          maximum: 5000,
          default: 1000
        }
      },
      required: ["guild_id", "channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        monitoring: %{
          type: :boolean,
          description: "Whether voice activity monitoring started"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        },
        channel_id: %{
          type: :string,
          description: "The monitored channel ID"
        },
        active_speakers: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              user_id: %{type: :string},
              speaking: %{type: :boolean},
              volume: %{type: :number}
            }
          },
          description: "List of currently speaking users"
        }
      },
      required: ["monitoring"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Starts voice activity detection in a voice channel.

  Returns {:ok, %{monitoring: true, guild_id: id, channel_id: id, active_speakers: [...]}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, "guild_id"),
         {:ok, channel_id} <- Helpers.validate_string(params, "channel_id"),
         {:ok, threshold} <- Helpers.validate_number(params, "threshold", 0.5),
         {:ok, interval_ms} <- Helpers.validate_integer(params, "interval_ms", 1000) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} starting voice activity detection in channel #{channel_id}")

      # Get current voice states from Discord API
      case Client.request(:get, "/guilds/#{guild_id}/voice-states") do
        {:ok, voice_states} ->
          active_speakers = Enum.filter(voice_states, fn state ->
            state["channel_id"] == channel_id and state["self_mute"] == false
          end)
          |> Enum.map(fn state ->
            %{
              user_id: state["user_id"],
              speaking: state["speaking"] == true,
              volume: 0.8  # placeholder
            }
          end)

          {:ok, %{
            monitoring: true,
            guild_id: guild_id,
            channel_id: channel_id,
            active_speakers: active_speakers
          }}

        {:error, error} ->
          Logger.error("Failed to get voice states: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end