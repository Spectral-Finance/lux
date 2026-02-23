defmodule Lux.Prisms.Discord.Moderation.KickUser do
  @moduledoc """
  A prism for kicking a member from a Discord guild.

  Kicking removes the user from the guild without a permanent ban;
  they can rejoin via an invite.

  ## Examples
      iex> KickUser.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   user_id: "987654321098765432"
      ...> }, %{name: "Agent"})
      {:ok, %{kicked: true, user_id: "987654321098765432", guild_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Kick Discord User",
    description: "Kicks a member from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the member to kick",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        kicked: %{type: :boolean, description: "Whether the user was successfully kicked"},
        user_id: %{type: :string, description: "The ID of the kicked user"},
        guild_id: %{type: :string, description: "The ID of the guild"}
      },
      required: ["kicked"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_snowflake(params, :guild_id),
         {:ok, user_id} <- validate_snowflake(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} kicking user #{user_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}", %{}) do
        {:ok, _} ->
          Logger.info("Successfully kicked user #{user_id} from guild #{guild_id}")
          {:ok, %{kicked: true, user_id: user_id, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to kick user #{user_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to kick user #{user_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
