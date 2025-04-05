defmodule Lux.Prisms.Discord.Guilds.KickMember do
  @moduledoc """
  A prism for kicking a member from a Discord server (guild).

  ## Examples
      iex> KickMember.handler(%{
      ...>   guild_id: "987654321",
      ...>   user_id: "123456789"
      ...> }, %{name: "Agent"})
      {:ok, %{kicked: true, guild_id: "987654321", user_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Kick Discord Guild Member",
    description: "Kicks a member from a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to kick the member from",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to kick",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        kicked: %{
          type: :boolean,
          description: "Whether the member was successfully kicked"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild the member was kicked from"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user that was kicked"
        }
      },
      required: ["kicked", "guild_id", "user_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to kick a member from a Discord server.

  Returns {:ok, %{kicked: true, guild_id: guild_id, user_id: user_id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} kicking user #{user_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}") do
        {:ok, _response} ->
          Logger.info("Successfully kicked user #{user_id} from guild #{guild_id}")
          {:ok, %{
            kicked: true,
            guild_id: guild_id,
            user_id: user_id
          }}
        error ->
          Logger.error("Failed to kick user #{user_id} from guild #{guild_id}: #{inspect(error)}")
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
