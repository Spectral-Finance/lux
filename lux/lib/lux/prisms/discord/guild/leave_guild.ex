defmodule Lux.Prisms.Discord.Guild.LeaveGuild do
  use Lux.Prism,
    name: "Leave Discord Guild",
    description: "Leaves a Discord guild (server)",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild to leave"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        left: %{type: :boolean, description: "Whether the guild was successfully left"},
        guild_id: %{type: :string, description: "The ID of the guild"}
      },
      required: ["left"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} leaving guild #{guild_id}")

      case Client.request(:delete, "/users/@me/guilds/#{guild_id}") do
        {:ok, _} ->
          {:ok, %{left: true, guild_id: guild_id}}
        {:error, error} ->
          Logger.error("Failed to leave guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end\n