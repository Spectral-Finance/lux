defmodule Lux.Lenses.Discord.Guilds.GetGuildMember do
  @moduledoc """
  A lens for reading Discord guild member information.
  This lens provides a simple interface for reading guild member details with:
  - Required parameters (guild_id, user_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> GetGuildMember.focus(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321"
      ...> })
      {:ok, %{
        user: %{
          id: "987654321",
          username: "example_user"
        },
        nick: "Custom Nickname",
        roles: ["123456789", "234567890"],
        joined_at: "2021-01-01T00:00:00.000000+00:00"
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Guild Member",
    description: "Reads member information from a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/members/:user_id",
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
        user_id: %{
          type: :string,
          description: "The ID of the user",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.

  ## Examples
      iex> after_focus(%{
      ...>   "user" => %{
      ...>     "id" => "987654321",
      ...>     "username" => "example_user"
      ...>   },
      ...>   "nick" => "Custom Nickname",
      ...>   "roles" => ["123456789", "234567890"],
      ...>   "joined_at" => "2021-01-01T00:00:00.000000+00:00"
      ...> })
      {:ok, %{
        user: %{
          id: "987654321",
          username: "example_user"
        },
        nick: "Custom Nickname",
        roles: ["123456789", "234567890"],
        joined_at: "2021-01-01T00:00:00.000000+00:00"
      }}
  """
  @impl true
  def after_focus(%{
    "user" => %{"id" => id, "username" => username} = _user,
    "nick" => nick,
    "roles" => roles,
    "joined_at" => joined_at
  }) do
    {:ok, %{
      user: %{
        id: id,
        username: username
      },
      nick: nick,
      roles: roles,
      joined_at: joined_at
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
