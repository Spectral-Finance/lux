defmodule Lux.Lenses.Discord.Member.GetMember do
  use Lux.Lens,
    name: "Get Discord Member",
    description: "Gets information about a Discord guild member"

  alias Lux.Integrations.Discord.Client

  def focus(params, _agent) do
    guild_id = params[:guild_id] || params["guild_id"]
    user_id = params[:user_id] || params["user_id"]
    case Client.request(:get, "/guilds/#{guild_id}/members/#{user_id}") do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, error}
    end
  end
end\n