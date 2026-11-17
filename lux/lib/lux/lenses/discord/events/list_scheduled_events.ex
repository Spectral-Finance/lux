defmodule Lux.Lenses.Discord.Events.ListScheduledEvents do
  @moduledoc """
  A lens for listing scheduled events in a Discord guild.

  ## Examples
      iex> ListScheduledEvents.focus(%{guild_id: "123456789"})
      {:ok, [
        %{
          id: "111111111111111111",
          name: "Community Meetup",
          scheduled_start_time: "2024-12-25T18:00:00+00:00",
          status: 1,
          entity_type: 3
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Scheduled Events",
    description: "Lists all scheduled events in a Discord guild",
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
        },
        with_user_count: %{
          type: :boolean,
          description: "Include number of users subscribed to each event",
          default: false
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  """
  @impl true
  def after_focus(events) when is_list(events) do
    {:ok, Enum.map(events, &transform_event/1)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  defp transform_event(event) do
    %{
      id: event["id"],
      name: event["name"],
      description: event["description"],
      scheduled_start_time: event["scheduled_start_time"],
      scheduled_end_time: event["scheduled_end_time"],
      status: event["status"],
      entity_type: event["entity_type"],
      creator_id: get_in(event, ["creator", "id"])
    }
  end
end
