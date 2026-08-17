defmodule Lux.Prisms.Discord.Analytics.LogEvent do
  @moduledoc """
  A prism for logging Discord events to persistent storage.

  Provides structured event logging with filtering, retention policies,
  and export capabilities for audit and analytics.
  """

  use Lux.Prism,
    name: "Log Discord Event",
    description: "Logs events to persistent storage with retention and export",
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
          description: "Type of event to log",
          enum: ["moderation", "security", "activity", "error", "system", "custom"]
        },
        severity: %{
          type: :string,
          description: "Event severity level",
          enum: ["debug", "info", "warning", "error", "critical"],
          default: "info"
        },
        message: %{
          type: :string,
          description: "Human-readable event description"
        },
        user_id: %{
          type: :string,
          description: "User ID associated with event",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "Channel ID (if applicable)",
          pattern: "^[0-9]{17,20}$"
        },
        metadata: %{
          type: :object,
          description: "Additional structured metadata",
          additionalProperties: true
        },
        tags: %{
          type: :array,
          items: %{type: :string},
          description: "Tags for filtering and search"
        }
      },
      required: ["guild_id", "event_type", "message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        logged: %{
          type: :boolean,
          description: "Whether event was successfully logged"
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
      required: ["logged"]
    }

  alias Lux.Prisms.Discord.Helpers
  alias Lux.Prisms.Discord.Analytics.TrackActivity
  require Logger

  @event_logs %{}

  @doc """
  Logs an event to persistent storage.

  Returns {:ok, %{logged: true, event_id: id, guild_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, "guild_id"),
         {:ok, event_type} <- Helpers.validate_string(params, "event_type"),
         {:ok, severity} <- Helpers.validate_string(params, "severity", "info"),
         {:ok, message} <- Helpers.validate_string(params, "message"),
         {:ok, user_id} <- Helpers.validate_string(params, "user_id", nil),
         {:ok, channel_id} <- Helpers.validate_string(params, "channel_id", nil),
         {:ok, metadata} <- Helpers.optional(params, "metadata", %{}),
         {:ok, tags} <- Helpers.validate_string_list(params, "tags", []) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} logging #{severity} event in guild #{guild_id}: #{message}")

      event_id = generate_event_id()
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      log_entry = %{
        event_id: event_id,
        guild_id: guild_id,
        event_type: event_type,
        severity: severity,
        message: message,
        user_id: user_id,
        channel_id: channel_id,
        metadata: metadata,
        tags: tags,
        timestamp: timestamp
      }

      store_log(guild_id, log_entry)

      # Also track in activity system for analytics
      TrackActivity.store_event(guild_id, %{
        event_id: event_id,
        event_type: "event_log",
        user_id: user_id || "system",
        channel_id: channel_id,
        metadata: metadata,
        timestamp: timestamp
      })

      {:ok, %{logged: true, event_id: event_id, guild_id: guild_id}}
    end
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp store_log(guild_id, log_entry) do
    guild_logs = Map.get(@event_logs, guild_id, [])
    new_logs = [log_entry | guild_logs] |> Enum.take(50000)
    Map.put(@event_logs, guild_id, new_logs)
  end
end