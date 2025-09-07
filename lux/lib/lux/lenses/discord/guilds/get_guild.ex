defmodule Lux.Lenses.Discord.Guilds.GetGuild do
  @moduledoc """
  A lens for reading Discord guild (server) information.
  This lens provides a simple interface for reading Discord guild details with:
  - Minimal required parameters (guild_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> GetGuild.focus(%{
      ...>   guild_id: "123456789012345678"
      ...> })
      {:ok, %{
        id: "123456789012345678",
        name: "My Server",
        icon: "1234567890abcdef",
        owner_id: "876543210987654321",
        permissions: "1071698529857",
        features: ["COMMUNITY", "NEWS"],
        member_count: 42
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Guild",
    description: "Reads guild information from Discord",
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
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  ## Examples
      iex> after_focus(%{
      ...>   "id" => "123456789012345678",
      ...>   "name" => "My Server",
      ...>   "icon" => "1234567890abcdef",
      ...>   "owner_id" => "876543210987654321",
      ...>   "permissions" => "1071698529857",
      ...>   "features" => ["COMMUNITY", "NEWS"],
      ...>   "member_count" => 42
      ...> })
      {:ok, %{
        id: "123456789012345678",
        name: "My Server",
        icon: "1234567890abcdef",
        owner_id: "876543210987654321",
        permissions: "1071698529857",
        features: ["COMMUNITY", "NEWS"],
        member_count: 42
      }}
  """
  @impl true
  def after_focus(%{
        "id" => id,
        "name" => name,
        "icon" => icon,
        "owner_id" => owner_id,
        "permissions" => permissions,
        "features" => features,
        "member_count" => member_count
      }) do
    {:ok, %{
      id: id,
      name: name,
      icon: icon,
      owner_id: owner_id,
      permissions: permissions,
      features: features,
      member_count: member_count
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
