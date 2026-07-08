defmodule Lux.Lenses.Discord.Channels.ReadChannel do
  @moduledoc """
  A lens for reading Discord channel information.
  This lens provides a simple interface for reading Discord channel details with:
  - Minimal required parameters (channel_id)
  - Direct Discord API error propagation
  - Clean response structure
  ## Examples
      iex> ReadChannel.focus(%{
      ...>   channel_id: "123456789"
      ...> })
      {:ok, %{
        id: "123456789",
        name: "general",
        type: 0,
        guild_id: "987654321"
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Channel",
    description: "Reads channel information from Discord",
    url: "https://discord.com/api/v10/channels/:channel_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to read",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  ## Examples
      iex> after_focus(%{
      ...>   "id" => "123456789",
      ...>   "name" => "general",
      ...>   "type" => 0,
      ...>   "guild_id" => "987654321"
      ...> })
      {:ok, %{
        id: "123456789",
        name: "general",
        type: 0,
        guild_id: "987654321"
      }}
  """
  @impl true
  def after_focus(%{"id" => id, "name" => name, "type" => type, "guild_id" => guild_id}) do
    {:ok, %{
      id: id,
      name: name,
      type: type,
      guild_id: guild_id
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
