defmodule Lux.Lenses.Discord.Guilds.ListEmojis do
  @moduledoc """
  A lens for listing custom emojis in a Discord guild.
  This lens provides a simple interface for fetching emojis with:
  - Minimal required parameters (guild_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> ListEmojis.focus(%{
      ...>   guild_id: "123456789"
      ...> })
      {:ok, [
        %{
          id: "987654321",
          name: "custom_emoji",
          roles: ["role1", "role2"],
          user: %{
            id: "111222333",
            username: "creator"
          },
          require_colons: true,
          managed: false,
          animated: false,
          available: true
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Emojis",
    description: "Lists custom emojis in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/emojis",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list emojis from",
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
      ...>     "id" => "123",
      ...>     "name" => "custom_emoji",
      ...>     "roles" => ["role1"],
      ...>     "user" => %{"id" => "456", "username" => "creator"},
      ...>     "require_colons" => true,
      ...>     "managed" => false,
      ...>     "animated" => false,
      ...>     "available" => true
      ...>   }
      ...> ])
      {:ok, [
        %{
          id: "123",
          name: "custom_emoji",
          roles: ["role1"],
          user: %{id: "456", username: "creator"},
          require_colons: true,
          managed: false,
          animated: false,
          available: true
        }
      ]}
  """
  @impl true
  def after_focus(emojis) when is_list(emojis) do
    {:ok, Enum.map(emojis, &transform_emoji/1)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  defp transform_emoji(%{
    "id" => id,
    "name" => name,
    "roles" => roles,
    "user" => user,
    "require_colons" => require_colons,
    "managed" => managed,
    "animated" => animated,
    "available" => available
  }) do
    %{
      id: id,
      name: name,
      roles: roles,
      user: %{
        id: user["id"],
        username: user["username"]
      },
      require_colons: require_colons,
      managed: managed,
      animated: animated,
      available: available
    }
  end
end
