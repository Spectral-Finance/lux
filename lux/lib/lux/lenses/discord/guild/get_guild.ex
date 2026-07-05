defmodule Lux.Lenses.Discord.Guild.GetGuild do
  use Lux.Lens,
    name: "Get Discord Guild",
    description: "Gets information about a Discord guild"

  alias Lux.Integrations.Discord.Client
  require Logger

  def focus(params, _agent) do
    guild_id = params[:guild_id] || params["guild_id"]
    case Client.request(:get, "/guilds/#{guild_id}") do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, error}
    end
  end
end\n