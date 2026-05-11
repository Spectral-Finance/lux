defmodule Lux.Prisms.Discord.Member.GetMember do
  use Lux.Prism,
    name: "Get Discord Guild Member",
    description: "Retrieves information about a guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "User ID", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string},
        username: %{type: :string},
        roles: %{type: :array, items: %{type: :string}},
        joined_at: %{type: :string}
      },
      required: ["user_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    case Client.request(:get, "/guilds/#{params[:guild_id]}/members/#{params[:user_id]}", %{}) do
      {:ok, member} ->
        {:ok, %{
          user_id: member["user"]["id"],
          username: member["user"]["username"],
          roles: member["roles"] || [],
          joined_at: member["joined_at"]
        }}
      {:error, error} -> {:error, error}
    end
  end
end
