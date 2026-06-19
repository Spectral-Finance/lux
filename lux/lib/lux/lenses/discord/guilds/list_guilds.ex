defmodule Lux.Lenses.Discord.Guilds.ListGuilds do
  @moduledoc """
  A lens for listing Discord guilds of which the bot user is a member.

  Supports pagination parameters:
  - limit: max number of guilds to return (1-200, default: 200)
  - before: guild ID to list guilds before
  - after: guild ID to list guilds after
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Guilds",
    description: "Lists the guilds the bot user is a member of",
    url: "https://discord.com/api/v10/users/@me/guilds",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        before: %{
          type: :string,
          description: "List guilds before this guild ID",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "List guilds after this guild ID",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Max number of guilds to return (1-200)",
          minimum: 1,
          maximum: 200
        }
      }
    }

  @doc """
  Transforms the list of guilds response into a cleaner representation.
  """
  @impl true
  def after_focus(guilds) when is_list(guilds) do
    parsed_guilds =
      Enum.map(guilds, fn guild ->
        %{
          id: guild["id"],
          name: guild["name"],
          icon: guild["icon"],
          owner: guild["owner"],
          permissions: guild["permissions"],
          features: guild["features"]
        }
      end)

    {:ok, parsed_guilds}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  def after_focus(other), do: {:error, other}
end
