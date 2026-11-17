defmodule Lux.Lenses.Discord.Events.GetScheduledEvent do
  @moduledoc """
  A lens for fetching a specific scheduled event from a Discord guild.

  ## Examples
      iex> GetScheduledEvent.focus(%{guild_id: "123456789", event_id: "111111111111111111"})
      {:ok, %{
        id: "111111111111111111",
        name: "Community Meetup",
        scheduled_start_time: "2024-12-25T18:00:00+00:00",
        status: 1,
        entity_type: 3
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Scheduled Event",
    description: "Fetches a specific scheduled event from a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/scheduled-events/:event_id",
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
        event_id: %{
          type: :string,
          description: "The ID of the scheduled event",
          pattern: "^[0-9]{17,20}$"
        },
        with_user_count: %{
          type: :boolean,
          description: "Include number of users subscribed",
          default: false
        }
      },
      required: ["guild_id", "event_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  """
  @impl true
  def after_focus(%{"id" => id, "name" => name} = event) do
    {:ok, %{
      id: id,
      name: name,
      description: event["description"],
      scheduled_start_time: event["scheduled_start_time"],
      scheduled_end_time: event["scheduled_end_time"],
      status: event["status"],
      entity_type: event["entity_type"],
      user_count: event["user_count"],
      creator_id: get_in(event, ["creator", "id"])
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
