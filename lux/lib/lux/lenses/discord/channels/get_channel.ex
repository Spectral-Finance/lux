defmodule Lux.Lenses.Discord.Channels.GetChannel do
  @moduledoc """
  A lens for fetching detailed information about a Discord channel.

  ## Examples
      iex> GetChannel.focus(%{channel_id: "123456789"})
      {:ok, %{
        id: "123456789",
        name: "general",
        type: 0,
        guild_id: "987654321",
        position: 1,
        topic: "General discussion"
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Channel",
    description: "Fetches detailed information about a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to fetch",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  """
  @impl true
  def after_focus(%{"id" => id, "name" => name, "type" => type} = channel) do
    {:ok, %{
      id: id,
      name: name,
      type: type,
      guild_id: channel["guild_id"],
      position: channel["position"],
      topic: channel["topic"],
      nsfw: channel["nsfw"],
      permission_overwrites: channel["permission_overwrites"]
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
