defmodule Lux.Lenses.Discord.Guilds.ReadGuild do
  @moduledoc """
  A lens for reading Discord guild information.

  Requires guild_id. Supports optional with_counts parameter.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Guild",
    description: "Reads detail of a specific Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to read",
          pattern: "^[0-9]{17,20}$"
        },
        with_counts: %{
          type: :boolean,
          description: "Whether to include approximate member and presence counts"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the guild details response into a cleaner format.
  """
  @impl true
  def after_focus(%{"id" => id, "name" => name} = guild) do
    {:ok,
     %{
       id: id,
       name: name,
       icon: guild["icon"],
       description: guild["description"],
       owner_id: guild["owner_id"],
       approximate_member_count: guild["approximate_member_count"],
       approximate_presence_count: guild["approximate_presence_count"]
     }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  def after_focus(other), do: {:error, other}
end
