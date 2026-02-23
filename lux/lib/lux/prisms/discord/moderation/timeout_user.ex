defmodule Lux.Prisms.Discord.Moderation.TimeoutUser do
  @moduledoc """
  A prism for applying a timeout to a Discord guild member.

  Sets `communication_disabled_until` on the guild member, preventing them
  from sending messages, joining voice channels, or interacting until the
  timeout expires. Pass `nil` for `until` to remove an active timeout.

  ## Examples
      iex> TimeoutUser.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   user_id: "987654321098765432",
      ...>   until: "2026-02-24T00:00:00Z"
      ...> }, %{name: "Agent"})
      {:ok, %{timed_out: true, user_id: "987654321098765432", until: "2026-02-24T00:00:00Z"}}
  """

  use Lux.Prism,
    name: "Timeout Discord User",
    description: "Applies or removes a communication timeout on a guild member",
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
          description: "The ID of the member to timeout",
          pattern: "^[0-9]{17,20}$"
        },
        until: %{
          type: :string,
          description: "ISO8601 timestamp until which the member is timed out. Pass null to remove timeout."
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timed_out: %{type: :boolean, description: "Whether the timeout was applied"},
        user_id: %{type: :string, description: "The ID of the affected member"},
        until: %{type: :string, description: "The timeout expiry timestamp"}
      },
      required: ["timed_out"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_snowflake(params, :guild_id),
         {:ok, user_id} <- validate_snowflake(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      until = Map.get(params, :until)
      Logger.info("Agent #{agent_name} setting timeout for user #{user_id} in guild #{guild_id} until #{inspect(until)}")

      body = %{communication_disabled_until: until}

      case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully set timeout for user #{user_id}")
          {:ok, %{timed_out: true, user_id: user_id, until: until}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to timeout user #{user_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to timeout user #{user_id}: #{inspect(error)}")
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
