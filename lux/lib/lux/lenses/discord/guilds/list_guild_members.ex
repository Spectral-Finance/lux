defmodule Lux.Lenses.Discord.Guilds.ListGuildMembers do
  @moduledoc """
  A lens for reading Discord guild members.
  This lens provides a simple interface for reading guild members with:
  - Minimal required parameters (guild_id)
  - Optional pagination support (limit, after)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> ListGuildMembers.focus(%{
      ...>   "guild_id" => "123456789"
      ...> })
      {:ok, [
        %{
          user: %{
            id: "111222333",
            username: "user1",
            avatar: "avatar1"
          },
          nick: "nickname1",
          roles: ["role1", "role2"],
          joined_at: "2023-01-01T00:00:00.000Z"
        }
      ]}

      iex> ListGuildMembers.focus(%{
      ...>   "guild_id" => "123456789",
      ...>   "limit" => 50,
      ...>   "after" => "111222333"
      ...> })
      {:ok, [
        %{
          user: %{
            id: "444555666",
            username: "user2",
            avatar: "avatar2"
          },
          nick: "nickname2",
          roles: ["role2", "role3"],
          joined_at: "2023-01-02T00:00:00.000Z"
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Guild Members",
    description: "Lists members from a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/members",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to fetch members from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Max number of members to return (1-1000)",
          minimum: 1,
          maximum: 1000
        },
        after: %{
          type: :string,
          description: "The highest user ID in the previous page",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  ## Examples
      iex> after_focus([
      ...>   %{
      ...>     "user" => %{
      ...>       "id" => "111222333",
      ...>       "username" => "user1",
      ...>       "avatar" => "avatar1"
      ...>     },
      ...>     "nick" => "nickname1",
      ...>     "roles" => ["role1", "role2"],
      ...>     "joined_at" => "2023-01-01T00:00:00.000Z",
      ...>     "premium_since" => nil,
      ...>     "pending" => false,
      ...>     "communication_disabled_until" => nil
      ...>   }
      ...> ])
      {:ok, [
        %{
          user: %{
            id: "111222333",
            username: "user1",
            avatar: "avatar1"
          },
          nick: "nickname1",
          roles: ["role1", "role2"],
          joined_at: "2023-01-01T00:00:00.000Z",
          premium_since: nil,
          pending: false,
          communication_disabled_until: nil
        }
      ]}
  """
  @impl true
  def after_focus(members) when is_list(members) do
    transformed_members =
      Enum.map(members, fn %{
                           "user" => %{"id" => id, "username" => username, "avatar" => avatar},
                           "nick" => nick,
                           "roles" => roles,
                           "joined_at" => joined_at,
                           "premium_since" => premium_since,
                           "pending" => pending,
                           "communication_disabled_until" => communication_disabled_until
                         } ->
        %{
          user: %{
            id: id,
            username: username,
            avatar: avatar
          },
          nick: nick,
          roles: roles,
          joined_at: joined_at,
          premium_since: premium_since,
          pending: pending,
          communication_disabled_until: communication_disabled_until
        }
      end)

    {:ok, transformed_members}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
