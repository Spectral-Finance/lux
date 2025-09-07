defmodule Lux.Lenses.Discord.Interactions.ReadButtonClick do
  @moduledoc """
  A lens for reading Discord button click interaction data.
  This lens provides a simple interface for reading button click details with:
  - Minimal required parameters (interaction_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples

      iex> ReadButtonClick.focus(%{
      ...>   interaction_id: "123456789"
      ...> })
      {:ok, %{
        id: "123456789",
        custom_id: "confirm_button",
        message_id: "987654321",
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
    name: "Read Discord Button Click",
    description: "Reads button click interaction data from Discord",
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
    "data" => %{"custom_id" => custom_id},
    "message" => %{"id" => message_id},
    "guild_id" => guild_id,
    "channel_id" => channel_id,
    "member" => %{
      "user" => %{"id" => user_id, "username" => username},
      "roles" => roles
    }
  }) do
    {:ok, %{
      id: id,
      custom_id: custom_id,
      message_id: message_id,
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
