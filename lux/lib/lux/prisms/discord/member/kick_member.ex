defmodule Lux.Prisms.Discord.Member.KickMember do
  @moduledoc """
  A prism for removing a Discord member from a guild.
  """

  use Lux.Prism,
    name: "Kick Discord Member",
    description: "Removes a member from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "User ID to kick", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        kicked: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string}
      },
      required: ["kicked"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} kicking member #{user_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}") do
        {:ok, _} ->
          Logger.info("Successfully kicked member #{user_id} from guild #{guild_id}")
          {:ok, %{kicked: true, guild_id: guild_id, user_id: user_id}}

        error ->
          Logger.error(
            "Failed to kick member #{user_id} from guild #{guild_id}: #{inspect(error)}"
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
