defmodule Lux.Prisms.Discord.GuildEvents.DeleteScheduledEvent do
  @moduledoc """
  A prism for deleting a scheduled event from a Discord guild.

  ## Examples
      iex> DeleteScheduledEvent.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   event_id: "111111111111111111"
      ...> }, %{name: "Agent"})
      {:ok, %{deleted: true, event_id: "111111111111111111", guild_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Delete Discord Scheduled Event",
    description: "Deletes a scheduled event from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        event_id: %{
          type: :string,
          description: "The ID of the scheduled event to delete",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "event_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean, description: "Whether the event was deleted"},
        event_id: %{type: :string, description: "The ID of the deleted event"},
        guild_id: %{type: :string, description: "The ID of the guild"}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_snowflake(params, :guild_id),
         {:ok, event_id} <- validate_snowflake(params, :event_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting event #{event_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/scheduled-events/#{event_id}", %{}) do
        {:ok, _} ->
          Logger.info("Successfully deleted event #{event_id} from guild #{guild_id}")
          {:ok, %{deleted: true, event_id: event_id, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to delete event #{event_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to delete event #{event_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
