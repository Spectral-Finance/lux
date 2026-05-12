defmodule Lux.Prisms.Discord.Member.BanMember do
  @moduledoc """
  A prism for banning a Discord member from a guild.
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a member from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "User ID to ban", pattern: "^[0-9]{17,20}$"},
        delete_message_seconds: %{
          type: :integer,
          description: "Seconds of recent messages to delete",
          minimum: 0,
          maximum: 604_800
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string},
        delete_message_seconds: %{type: :integer}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      delete_message_seconds = Map.get(params, :delete_message_seconds)
      Logger.info("Agent #{agent_name} banning member #{user_id} from guild #{guild_id}")

      request_body =
        case delete_message_seconds do
          nil -> %{}
          seconds -> %{delete_message_seconds: seconds}
        end

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{json: request_body}) do
        {:ok, _} ->
          Logger.info("Successfully banned member #{user_id} from guild #{guild_id}")

          {:ok,
           %{
             banned: true,
             guild_id: guild_id,
             user_id: user_id,
             delete_message_seconds: delete_message_seconds
           }}

        error ->
          Logger.error(
            "Failed to ban member #{user_id} from guild #{guild_id}: #{inspect(error)}"
          )

          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
