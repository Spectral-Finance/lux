defmodule Lux.Prisms.Discord.Moderation.UnbanMember do
  @moduledoc """
  A prism for unbanning a member from a Discord guild.

  ## Examples
      iex> UnbanMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321"
      ...> }, %{name: "Agent"})
      {:ok, %{unbanned: true, user_id: "987654321", guild_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Unban Discord Member",
    description: "Removes a ban for a member in a Discord guild",
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
          description: "The ID of the user to unban",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unbanned: %{
          type: :boolean,
          description: "Whether the user was successfully unbanned"
        },
        user_id: %{
          type: :string,
          description: "The ID of the unbanned user"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["unbanned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to unban a member from a guild.

  Returns {:ok, %{unbanned: true, user_id: id, guild_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} unbanning user #{user_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}") do
        {:ok, _} ->
          Logger.info("Successfully unbanned user #{user_id} from guild #{guild_id}")
          {:ok, %{unbanned: true, user_id: user_id, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to unban user #{user_id} from guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to unban user #{user_id} from guild #{guild_id}: #{inspect(error)}")
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
end
