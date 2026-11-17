defmodule Lux.Prisms.Discord.Moderation.BanMember do
  @moduledoc """
  A prism for banning a member from a Discord guild.

  Supports optional message deletion (up to 7 days of messages)
  and an audit log reason.

  ## Examples
      iex> BanMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   delete_message_seconds: 86400,
      ...>   reason: "Spam"
      ...> }, %{name: "Agent"})
      {:ok, %{banned: true, user_id: "987654321", guild_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Ban Discord Member",
    description: "Bans a member from a Discord guild",
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
          description: "The ID of the user to ban",
          pattern: "^[0-9]{17,20}$"
        },
        delete_message_seconds: %{
          type: :integer,
          description: "Number of seconds to delete messages for (0-604800)",
          minimum: 0,
          maximum: 604800,
          default: 0
        },
        reason: %{
          type: :string,
          description: "Reason for the ban (shown in audit log)",
          maxLength: 512
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{
          type: :boolean,
          description: "Whether the user was successfully banned"
        },
        user_id: %{
          type: :string,
          description: "The ID of the banned user"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to ban a member from a guild.

  Returns {:ok, %{banned: true, user_id: id, guild_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} from guild #{guild_id}")

      body = %{}
      body = if params[:delete_message_seconds], do: Map.put(body, :delete_message_seconds, params[:delete_message_seconds]), else: body

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully banned user #{user_id} from guild #{guild_id}")
          {:ok, %{banned: true, user_id: user_id, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to ban user #{user_id} from guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to ban user #{user_id} from guild #{guild_id}: #{inspect(error)}")
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
