defmodule Lux.Prisms.Discord.Moderation.BanUser do
  @moduledoc """
  A prism for banning a user from a Discord guild.

  This prism provides a simple interface for banning Discord members with:
  - Required parameters (guild_id, user_id)
  - Optional delete_message_seconds to purge recent messages
  - Direct Discord API error propagation

  ## Examples
      iex> BanUser.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   user_id: "987654321098765432",
      ...>   delete_message_seconds: 86400
      ...> }, %{name: "Agent"})
      {:ok, %{banned: true, user_id: "987654321098765432", guild_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Ban Discord User",
    description: "Bans a user from a Discord guild",
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
          description: "Number of seconds of messages to delete (0-604800)",
          minimum: 0,
          maximum: 604_800
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean, description: "Whether the user was successfully banned"},
        user_id: %{type: :string, description: "The ID of the banned user"},
        guild_id: %{type: :string, description: "The ID of the guild"}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_snowflake(params, :guild_id),
         {:ok, user_id} <- validate_snowflake(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} from guild #{guild_id}")

      body = case Map.get(params, :delete_message_seconds) do
        nil -> %{}
        secs when is_integer(secs) -> %{delete_message_seconds: secs}
        _ -> %{}
      end

      case Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully banned user #{user_id} from guild #{guild_id}")
          {:ok, %{banned: true, user_id: user_id, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to ban user #{user_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to ban user #{user_id}: #{inspect(error)}")
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
