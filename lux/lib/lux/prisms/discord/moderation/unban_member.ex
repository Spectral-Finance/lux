defmodule Lux.Prisms.Discord.Moderation.UnbanMember do
  @moduledoc """
  A prism for removing a Discord guild ban.
  """

  use Lux.Prism,
    name: "Unban Discord Member",
    description: "Removes a ban for a user in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        reason: %{type: :string}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unbanned: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string}
      },
      required: ["unbanned"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, user_id} <- Helpers.validate_string(params, :user_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} unbanning user #{user_id} from guild #{guild_id}")

      case Client.request_with_retry(
             :delete,
             "/guilds/#{guild_id}/bans/#{user_id}",
             Helpers.client_opts(params)
           ) do
        {:ok, _} ->
          {:ok, %{unbanned: true, guild_id: guild_id, user_id: user_id}}

        error ->
          Logger.error("Failed to unban Discord user #{user_id}: #{inspect(error)}")
          error
      end
    end
  end
end
