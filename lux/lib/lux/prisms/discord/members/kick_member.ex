defmodule Lux.Prisms.Discord.Members.KickMember do
  @moduledoc """
  A prism for kicking members from a Discord guild.

  Provides:
  - Minimal required parameters (guild_id, user_id)
  - Optional reason for audit log
  - Direct Discord API error propagation

  ## Examples
      iex> KickMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   reason: "Violating community guidelines"
      ...> }, %{name: "Agent"})
      {:ok, %{
        kicked: true,
        user_id: "987654321",
        guild_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Kick Discord Member",
    description: "Removes a member from a Discord guild",
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
        },
        reason: %{
          type: :string,
          description: "Reason for the kick (audit log)",
          maxLength: 512
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
        user_id: %{
          type: :string,
          description: "The ID of the kicked user"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["kicked"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} kicking user #{user_id} from guild #{guild_id}")

      headers = []
      reason = params[:reason]

      headers =
        if reason do
          [{"X-Audit-Log-Reason", reason} | headers]
        else
          headers
        end

      case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}", %{headers: headers}) do
        {:ok, _} ->
          Logger.info("Successfully kicked user #{user_id} from guild #{guild_id}")
          {:ok, %{kicked: true, user_id: user_id, guild_id: guild_id}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to kick user #{user_id} from guild #{guild_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to kick user #{user_id} from guild #{guild_id}: #{inspect(error)}")
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
