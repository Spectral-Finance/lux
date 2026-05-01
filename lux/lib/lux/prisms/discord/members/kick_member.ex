defmodule Lux.Prisms.Discord.Members.KickMember do
  @moduledoc """
  A prism for kicking a member from a Discord server.

  ## Examples

      iex> KickMember.handler(%{
      ...>   guild_id: "111111111111111111",
      ...>   user_id: "222222222222222222",
      ...>   reason: "Violation of rules"
      ...> }, %{name: "Agent"})
      {:ok, %{kicked: true, user_id: "222222222222222222", guild_id: "111111111111111111"}}
  """

  use Lux.Prism,
    name: "Kick Discord Member",
    description: "Kicks a member from a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to kick",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "Optional audit log reason for the kick",
          maxLength: 500
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        kicked: %{type: :boolean, description: "Whether the member was successfully kicked"},
        user_id: %{type: :string, description: "The ID of the kicked user"},
        guild_id: %{type: :string, description: "The ID of the server"}
      },
      required: ["kicked"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} kicking user #{user_id} from server #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}", %{}) do
        {:ok, _} ->
          {:ok, %{kicked: true, user_id: user_id, guild_id: guild_id}}
        {:error, %{"status" => 204}} ->
          {:ok, %{kicked: true, user_id: user_id, guild_id: guild_id}}
        error ->
          Logger.error("Failed to kick member: #{inspect(error)}")
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
