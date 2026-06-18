defmodule Lux.Lenses.Discord.Guilds.ListGuilds do
  @moduledoc """
  A lens for listing guilds (servers) the bot is in.

  Provides a simple interface for fetching guilds with:
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> ListGuilds.focus(%{})
      {:ok, [
        %{
          id: "123456789",
          name: "My Server",
          owner_id: "987654321",
          member_count: 150
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Guilds",
    description: "Lists guilds (servers) the bot is a member of",
    url: "https://discord.com/api/v10/users/@me/guilds",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(guilds) when is_list(guilds) do
    {:ok,
     Enum.map(guilds, fn guild ->
       %{
         id: guild["id"],
         name: guild["name"],
         owner: guild["owner"],
         permissions: guild["permissions"],
         icon: guild["icon"]
       }
     end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
