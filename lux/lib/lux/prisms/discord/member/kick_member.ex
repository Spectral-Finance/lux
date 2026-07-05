defmodule Lux.Prisms.Discord.Member.KickMember do
  use Lux.Prism,
    name: "Kick Discord Member",
    description: "Kicks a member from a guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        user_id: %{type: :string}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        kicked: %{type: :boolean}
      },
      required: ["kicked"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _agent) do
    guild_id = params[:guild_id] || params["guild_id"]
    user_id = params[:user_id] || params["user_id"]

    case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}") do
      {:ok, _} -> {:ok, %{kicked: true}}
      {:error, error} -> {:error, error}
    end
  end
end\n