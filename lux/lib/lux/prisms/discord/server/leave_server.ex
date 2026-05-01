defmodule Lux.Prisms.Discord.Server.LeaveServer do
  @moduledoc """
  A prism for leaving a Discord server.

  This prism provides a simple interface for leaving Discord servers with:
  - Required parameters (guild_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples

      iex> LeaveServer.handler(%{
      ...>   guild_id: "111111111111111111",
      ...> }, %{name: "Agent"})
      {:ok, %{left: true, guild_id: "111111111111111111"}}
  """

  use Lux.Prism,
    name: "Leave Discord Server",
    description: "Leaves a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server to leave",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        left: %{
          type: :boolean,
          description: "Whether the server was successfully left"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the server that was left"
        }
      },
      required: ["left"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} leaving server #{guild_id}")

      case Client.request(:delete, "/users/@me/guilds/#{guild_id}", %{}) do
        {:ok, _} ->
          Logger.info("Successfully left server #{guild_id}")
          {:ok, %{left: true, guild_id: guild_id}}

        {:error, %{"status" => 204}} ->
          Logger.info("Successfully left server #{guild_id} (204)")
          {:ok, %{left: true, guild_id: guild_id}}

        error ->
          Logger.error("Failed to leave server #{guild_id}: #{inspect(error)}")
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
