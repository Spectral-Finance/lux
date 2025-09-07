defmodule Lux.Prisms.Discord.Guilds.SendEventReminder do
  @moduledoc """
  A prism for sending reminders about scheduled events in a Discord guild.

  This prism provides a simple interface for sending event reminders with:
  - Required parameters (guild_id, event_id, channel_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Example
      SendEventReminder.handler(%{
        guild_id: "123456789",
        event_id: "987654321",
        channel_id: "456789012"
      }, context)
  """

  use Lux.Prism,
    name: "Send Event Reminder",
    description: "Send a reminder about a scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      required: [:guild_id, :event_id, :channel_id],
      properties: %{
        guild_id: %{type: :string},
        event_id: %{type: :string},
        channel_id: %{type: :string}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean},
        event_id: %{type: :string},
        channel_id: %{type: :string}
      }
    }

  require Logger
  alias Lux.Integrations.Discord.Client

  @doc """
  Handles sending a reminder about a scheduled event in a Discord guild.
  """
  def handler(params, %{agent: agent} = _context) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, event_id} <- validate_param(params, :event_id),
         {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, event} <- fetch_event(guild_id, event_id),
         {:ok, request_data} <- build_reminder_message(event),
         {:ok, _response} <- send_message(channel_id, request_data) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sent reminder for event #{event_id} in channel #{channel_id}")

      {:ok, %{
        sent: true,
        event_id: event_id,
        channel_id: channel_id
      }}
    end
  end

  defp validate_param(params, key) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp fetch_event(guild_id, event_id) do
    case Client.request(:get, "/guilds/#{guild_id}/scheduled-events/#{event_id}") do
      {:ok, event} -> {:ok, event}
      {:error, {status, %{"message" => message}}} -> {:error, {status, message}}
      {:error, error} -> {:error, error}
    end
  end

  defp build_reminder_message(event) do
    start_time = event["scheduled_start_time"]
    location = get_event_location(event)
    event_url = "https://discord.com/events/#{event["guild_id"]}/#{event["id"]}"

    embed = %{
      title: "🔔 Event Reminder: #{event["name"]}",
      description: event["description"],
      color: 0x5865F2,
      fields: [
        %{
          name: "Start Time",
          value: "#{start_time}",
          inline: true
        },
        %{
          name: "Location",
          value: location,
          inline: true
        }
      ],
      footer: %{
        text: "Click the title to view event details"
      },
      url: event_url
    }

    {:ok, %{
      embeds: [embed]
    }}
  end

  defp get_event_location(%{"entity_type" => type, "channel_id" => channel_id}) when type in [1, 2] do
    "<##{channel_id}>"
  end
  defp get_event_location(%{"entity_metadata" => %{"location" => location}}), do: location
  defp get_event_location(_), do: "Location not specified"

  defp send_message(channel_id, request_data) do
    case Client.request(:post, "/channels/#{channel_id}/messages", %{json: request_data}) do
      {:ok, response} -> {:ok, response}
      {:error, {status, %{"message" => message}}} -> {:error, {status, message}}
      {:error, error} -> {:error, error}
    end
  end
end
