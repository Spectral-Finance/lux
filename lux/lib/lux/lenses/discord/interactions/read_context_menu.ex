defmodule Lux.Lenses.Discord.Interactions.ReadContextMenu do
  @moduledoc """
  A lens for reading Discord context menu interaction data.
  This lens provides a simple interface for reading context menu details with:
  - Minimal required parameters (interaction_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples

      iex> ReadContextMenu.focus(%{
      ...>   interaction_id: "123456789"
      ...> })
      {:ok, %{
        id: "123456789",
        command_id: "987654321",
        command_name: "Report Message",
        target_id: "444555666",
        target_type: 3,
        guild_id: "444555666",
        channel_id: "777888999",
        member: %{
          user_id: "111222333",
          username: "testuser",
          roles: ["role1", "role2"]
        }
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Context Menu",
    description: "Reads context menu interaction data from Discord",
    url: "https://discord.com/api/v10/interactions/:interaction_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        interaction_id: %{
          type: :string,
          description: "The ID of the interaction to read",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["interaction_id"]
    }

  @impl true
  def after_focus(%{
    "id" => id,
    "data" => %{
      "id" => command_id,
      "name" => command_name,
      "target_id" => target_id,
      "type" => target_type
    },
    "guild_id" => guild_id,
    "channel_id" => channel_id,
    "member" => %{
      "user" => %{"id" => user_id, "username" => username},
      "roles" => roles
    }
  }) do
    {:ok, %{
      id: id,
      command_id: command_id,
      command_name: command_name,
      target_id: target_id,
      target_type: target_type,
      guild_id: guild_id,
      channel_id: channel_id,
      member: %{
        user_id: user_id,
        username: username,
        roles: roles
      }
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
