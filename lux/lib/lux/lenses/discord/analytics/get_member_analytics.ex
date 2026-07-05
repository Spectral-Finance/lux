defmodule Lux.Lenses.Discord.Analytics.GetMemberAnalytics do
  use Lux.Lens,
    name: "Get Member Analytics",
    description: "Fetches analytics and event logs for guild members"

  alias Lux.Integrations.Discord.Client

  def focus(params) do
    guild_id = params.guild_id
    limit = Map.get(params, :limit, 100)
    
    case Client.request(:get, "/guilds/#{guild_id}/members?limit=#{limit}") do
      {:ok, members} ->
        {:ok, %{"total_members" => length(members), "members" => members}}
      {:error, {status, %{"message" => message}}} ->
        {:error, {status, message}}
      {:error, error} ->
        {:error, error}
    end
  end
end
