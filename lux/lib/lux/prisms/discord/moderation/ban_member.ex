defmodule Lux.Prisms.Discord.Moderation.BanMember do
  @moduledoc """
  A prism for banning a Discord guild member.
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a user from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        delete_message_seconds: %{
          type: :integer,
          description: "Seconds of message history to delete",
          minimum: 0,
          maximum: 604_800,
          default: 0
        },
        reason: %{type: :string}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, user_id} <- Helpers.validate_string(params, :user_id),
         {:ok, delete_message_seconds} <- Helpers.optional(params, :delete_message_seconds, 0) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} from guild #{guild_id}")

      opts = Helpers.client_opts(params, %{json: %{delete_message_seconds: delete_message_seconds}})

      case Client.request_with_retry(:put, "/guilds/#{guild_id}/bans/#{user_id}", opts) do
        {:ok, _} ->
          {:ok, %{banned: true, guild_id: guild_id, user_id: user_id}}

        error ->
          Logger.error("Failed to ban Discord user #{user_id}: #{inspect(error)}")
          error
      end
    end
  end
end
