defmodule Lux.Prisms.Discord.Analytics.TrackActivity do
  @moduledoc """
  A prism for tracking Discord server activity events.

  Records messages, reactions, voice state changes, member joins/leaves,
  and other server activities for analytics.
  """

  use Lux.Prism,
    name: "Track Discord Server Activity",
    description: "Tracks and records server activity events for analytics",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        event_type: %{
          type: :string,
          description: "Type of activity event",
          enum: ["message", "reaction_add", "reaction_remove", "voice_join", "voice_leave", "voice_move", "member_join", "member_leave", "member_ban", "member_unban", "channel_create", "channel_delete", "role_create", "role_delete"]
        },
        user_id: %{
          type: :string,
          description: "User ID associated with the event",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "Channel ID (for message/voice events)",
          pattern: "^[0-9]{17,20}$"
        },
        metadata: %{
          type: :object,
          description: "Additional event metadata",
          additionalProperties: true
        }
      },
      required: ["guild_id", "event_type", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tracked: %{
          type: :boolean,
          description: "Whether event was successfully tracked"
        },
        event_id: %{
          type: :string,
          description: "Unique event ID"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        }
      },
      required: ["tracked"]
    }

  alias Lux.Prisms.Discord.Helpers
  require Logger

  @activity_store %{}

  @doc """
  Tracks a server activity event.

  Returns {:ok, %{tracked: true, event_id: id, guild_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, "guild_id"),
         {:ok, event_type} <- Helpers.validate_string(params, "event_type"),
         {:ok, user_id} <- Helpers.validate_string(params, "user_id"),
         {:ok, channel_id} <- Helpers.validate_string(params, "channel_id", nil),
         {:ok, metadata} <- Helpers.optional(params, "metadata", %{}) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} tracking activity: #{event_type} in guild #{guild_id}")

      event_id = generate_event_id()
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      event = %{
        event_id: event_id,
        guild_id: guild_id,
        event_type: event_type,
        user_id: user_id,
        channel_id: channel_id,
        metadata: metadata,
        timestamp: timestamp
      }

      store_event(guild_id, event)

      {:ok, %{tracked: true, event_id: event_id, guild_id: guild_id}}
    end
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp store_event(guild_id, event) do
    guild_events = Map.get(@activity_store, guild_id, [])
    new_events = [event | guild_events] |> Enum.take(10000)
    Map.put(@activity_store, guild_id, new_events)
  end
end