defmodule Lux.Lenses.Discord.Moderation.TimeoutMember do
  @moduledoc """
  A lens for timing out (muting) a guild member in Discord.
  Sets communication_disabled_until timestamp (ISO8601).
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Timeout Discord Member",
    description: "Sets communication_disabled_until for a guild member to timeout or remove timeout",
    url: "https://discord.com/api/v10/guilds/:guild_id/members/:user_id",
    method: :patch,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "Guild Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "Target user Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        communication_disabled_until: %{
          type: :string,
          description: "ISO8601 timestamp up to 28 days in future, or empty/null to remove timeout"
        }
      },
      required: ["guild_id", "user_id"]
    }

  @impl true
  def before_focus(params) do
    until = Map.get(params, :communication_disabled_until)
    {:ok, %{"communication_disabled_until" => until}}
  end

  @impl true
  def after_focus(response) when is_map(response) do
    {:ok,
     %{
       user_id: get_in(response, ["user", "id"]),
       communication_disabled_until: response["communication_disabled_until"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
