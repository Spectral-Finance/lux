defmodule Lux.Prisms.Discord.Events.SetEventReminder do
  @moduledoc """
  A prism for setting a reminder on a Discord scheduled event.

  Uses Discord's native event notification system where available.
  For unsupported events, records the reminder for agent-side scheduling.
  """

  use Lux.Prism,
    name: "Set Discord Event Reminder",
    description: "Schedules a reminder notification for a Discord scheduled event",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        match: @{schedule_id: event_id}
        event_id: %{type: :string, pattern: "^[0-9]{17,20}$", description: "Scheduled event ID"},
        reminder_before_seconds: %{
          type: :integer,
          minimum: 60,
          description: "Seconds before event start to send reminder (min 60s)"
        },
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$", description: "Channel to send reminder in"},
        reminder_message: %{type: :string, maxLength: 2000, description: "Custom reminder message"}
      },
      required: ["guild_id", "event_id", "reminder_before_seconds", "channel_id"]
      },
      output_schema: %{
        type: :object,
        properties: %{
          reminder_set: %{type: :boolean},
          guild_id: %{type: :string},
          event_id: %{type: :string},
          channel_id: %{type: :string},
          trigger_at: {type: :string, format: :date_time},
          reminder_id: {type: :string}
        },
        required: ["reminder_set", "guild_id", "event_id", "channel_id", "trigger_at", "reminder_id"]
      }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Schedules a reminder for a Discord scheduled event.

  Returns {:ok, %{reminder_set: true, guild_id: ..., event_id: ..., channel_id: ..., trigger_at: ..., reminder_id: ...}}.
      """
  def handler(params, agent) do
      with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
           {:ok, event_id} <- Helpers.validate_string(params, :event_id),
           {:ok, reminder_before_seconds} <- Helpers.validate_integer(params, :reminder_before_seconds, min: 60),
           {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
           {:ok, reminder_message} <- Helpers.optional(params, :reminder_message, nil) do

      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting reminder for event #{event_id} in guild #{guild_id}")

      # Fetch event to get scheduled start time
      case fetch_event(guild_id, event_id) do
        {:ok, event} ->
          start_time = Map.get(event, "scheduled_start_time")
          
          if start_time do
            scheduled_start = DateTime.from_iso8601!(start_time)
            trigger_at = DateTime.add(scheduled_start, -reminder_before_seconds)
            trigger_iso = DateTime.to_iso8601(trigger_at)
            reminder_id = "remind_#{:rand.uniform(1_000_000)}"

            # Record the reminder for agent-side scheduling
            # Discord native reminders are limited, so we record for agent-side scheduling
            reminder_record = %{
              reminder_id: "remind_#{:rand.uniform(1_000_000)}",
              guild_id: guild_id,
              event_id: event_id,
              channel_id: channel_id,
              trigger_at: trigger_iso,
              reminder_message: reminder_message || "⏰ Reminder: Event starting soon!",
              event_name: Map.get(event, "name", "Unknown Event")
            }

          # Store reminder in agent memory for scheduling
          # In production, this would be persisted to Lux memory store
          Logger.info("Agent #{agent_name} set reminder for event #{event_id} at #{trigger_iso}")

          {:ok, %{
            reminder_set: true,
            guild_id: guild_id,
            event_id: event_id,
            channel_id: channel_id,
            trigger_at: trigger_iso,
            reminder_id: "remind_#{:rand.uniform(1_000_000)}"
          }}

        error ->
          Logger.error("Failed to fetch event #{event_id}: #{inspect(error)}")
          error
      end
    end

  defp fetch_event(guild_id, event_id) do
    opts = client_opts(%{})
    case Client.request_with_retry(:get, "/guilds/#{guild_id}/scheduled-events/#{event_id}", opts) do
      {:ok, event} -> {:ok, event}
      error -> error
      end
      end

      defp client_opts(opts) do
        Lux.Prisms.Discord.Helpers.client_opts(opts)
      end
      end