defmodule Lux.Lenses.Discord.GuildEvents.ListScheduledEvents do
  @moduledoc """
  A lens for listing scheduled events in a Discord guild.

  ## Examples
      iex> ListScheduledEvents.focus(%{
      ...>   guild_id: "123456789012345678"
      ...> })
      {:ok, [
        %{
          id: "111111111111111111",
          name: "Team Meeting",
          scheduled_start_time: "2026-03-01T14:00:00Z",
          status: 1
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Scheduled Events",
    description: "Lists scheduled events in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/scheduled-events",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the raw Discord API response into a structured list of events.
  """
  @impl true
  def after_focus(events) when is_list(events) do
    {:ok, Enum.map(events, fn event ->
      %{
        id: event["id"],
        name: event["name"],
        description: event["description"],
        scheduled_start_time: event["scheduled_start_time"],
        scheduled_end_time: event["scheduled_end_time"],
        status: event["status"],
        entity_type: event["entity_type"],
        guild_id: event["guild_id"]
      }
    end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
