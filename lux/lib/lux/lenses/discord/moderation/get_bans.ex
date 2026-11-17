defmodule Lux.Lenses.Discord.Moderation.GetBans do
  @moduledoc """
  A lens for fetching the ban list of a Discord guild.

  Supports pagination with limit, before, and after parameters.

  ## Examples
      iex> GetBans.focus(%{guild_id: "123456789"})
      {:ok, [
        %{user_id: "987654321", username: "banned_user", reason: "Spam"}
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Bans",
    description: "Fetches the ban list for a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/bans",
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
        limit: %{
          type: :integer,
          description: "Number of bans to return (1-1000)",
          minimum: 1,
          maximum: 1000,
          default: 1000
        },
        before: %{
          type: :string,
          description: "Get bans before this user ID",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "Get bans after this user ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  """
  @impl true
  def after_focus(bans) when is_list(bans) do
    {:ok, Enum.map(bans, fn %{"user" => user} = ban ->
      %{
        user_id: user["id"],
        username: user["username"],
        reason: ban["reason"]
      }
    end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
