defmodule Lux.Lenses.Discord.Guilds.ListStickers do
  @moduledoc """
  A lens for listing custom stickers in a Discord guild.
  This lens provides a simple interface for fetching stickers with:
  - Minimal required parameters (guild_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> ListStickers.focus(%{
      ...>   guild_id: "123456789"
      ...> })
      {:ok, [
        %{
          id: "987654321",
          name: "custom_sticker",
          description: "A cool sticker",
          tags: "cool,awesome",
          type: 1,
          format_type: 1,
          available: true,
          guild_id: "123456789",
          user: %{
            id: "111222333",
            username: "creator"
          }
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Stickers",
    description: "Lists custom stickers in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/stickers",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list stickers from",
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
      ...>     "name" => "custom_sticker",
      ...>     "description" => "A cool sticker",
      ...>     "tags" => "cool,awesome",
      ...>     "type" => 1,
      ...>     "format_type" => 1,
      ...>     "available" => true,
      ...>     "guild_id" => "456",
      ...>     "user" => %{"id" => "789", "username" => "creator"}
      ...>   }
      ...> ])
      {:ok, [
        %{
          id: "123",
          name: "custom_sticker",
          description: "A cool sticker",
          tags: "cool,awesome",
          type: 1,
          format_type: 1,
          available: true,
          guild_id: "456",
          user: %{id: "789", username: "creator"}
        }
      ]}
  """
  @impl true
  def after_focus(stickers) when is_list(stickers) do
    {:ok, Enum.map(stickers, &transform_sticker/1)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  defp transform_sticker(%{
    "id" => id,
    "name" => name,
    "description" => description,
    "tags" => tags,
    "type" => type,
    "format_type" => format_type,
    "available" => available,
    "guild_id" => guild_id,
    "user" => user
  }) do
    %{
      id: id,
      name: name,
      description: description,
      tags: tags,
      type: type,
      format_type: format_type,
      available: available,
      guild_id: guild_id,
      user: %{
        id: user["id"],
        username: user["username"]
      }
    }
  end
end
