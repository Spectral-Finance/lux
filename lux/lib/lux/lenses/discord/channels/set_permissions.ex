defmodule Lux.Lenses.Discord.Channels.SetPermissions do
  @moduledoc """
  A lens for setting and modifying permission overwrites for a role or member in a Discord channel.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Set Discord Channel Permissions",
    description: "Sets permission overwrites for a role or member in a channel",
    url: "https://discord.com/api/v10/channels/:channel_id/permissions/:overwrite_id",
    method: :put,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Target Discord channel Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        overwrite_id: %{
          type: :string,
          description: "Role or member Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        type: %{
          type: :integer,
          description: "0 for role, 1 for member"
        },
        allow: %{
          type: :string,
          description: "Bitwise value of allowed permissions"
        },
        deny: %{
          type: :string,
          description: "Bitwise value of denied permissions"
        }
      },
      required: ["channel_id", "overwrite_id", "type"]
    }

  @impl true
  def before_focus(params) do
    payload = %{
      "type" => params.type,
      "allow" => Map.get(params, :allow, "0"),
      "deny" => Map.get(params, :deny, "0")
    }

    {:ok, payload}
  end

  @impl true
  def after_focus("") do
    {:ok, %{status: :ok}}
  end

  def after_focus(nil) do
    {:ok, %{status: :ok}}
  end

  def after_focus(other), do: {:ok, other}
end
