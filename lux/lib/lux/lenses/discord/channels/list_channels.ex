defmodule Lux.Lenses.Discord.Channels.ListChannels do
  @moduledoc """
  A lens for listing channels in a Discord guild.
  This lens provides a simple interface for fetching channels with:
  - Minimal required parameters (guild_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> ListChannels.focus(%{
      ...>   guild_id: "123456789"
      ...> })
      {:ok, [
        %{
          id: "111111111111111111",
          name: "general",
          type: 0,
          guild_id: "123456789"
        },
        %{
          id: "222222222222222222",
          name: "announcements",
          type: 0,
          guild_id: "123456789"
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Channels",
    description: "Lists channels in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/channels",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list channels from",
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
      ...>     "name" => "general",
      ...>     "type" => 0,
      ...>     "guild_id" => "456"
      ...>   }
      ...> ])
      {:ok, [
        %{
          id: "123",
          name: "general",
          type: 0,
          guild_id: "456"
        }
      ]}
  """
  @impl true
  def after_focus(channels) when is_list(channels) do
    {:ok, Enum.map(channels, fn %{"id" => id, "name" => name, "type" => type, "guild_id" => guild_id} ->
      %{
        id: id,
        name: name,
        type: type,
        guild_id: guild_id
      }
    end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
