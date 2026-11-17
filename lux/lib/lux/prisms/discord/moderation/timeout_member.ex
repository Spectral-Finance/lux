defmodule Lux.Prisms.Discord.Moderation.TimeoutMember do
  @moduledoc """
  A prism for timing out a member in a Discord guild.

  Sets or removes a communication timeout on a guild member. When timed out,
  the member cannot send messages, react, or join voice channels.

  ## Examples
      iex> TimeoutMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   communication_disabled_until: "2024-12-31T23:59:59Z"
      ...> }, %{name: "Agent"})
      {:ok, %{timed_out: true, user_id: "987654321", guild_id: "123456789",
              until: "2024-12-31T23:59:59Z"}}

      # Remove timeout
      iex> TimeoutMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   communication_disabled_until: nil
      ...> }, %{name: "Agent"})
      {:ok, %{timed_out: true, user_id: "987654321", guild_id: "123456789", until: nil}}
  """

  use Lux.Prism,
    name: "Timeout Discord Member",
    description: "Sets or removes a communication timeout on a guild member",
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
          description: "The ID of the user to timeout",
          pattern: "^[0-9]{17,20}$"
        },
        communication_disabled_until: %{
          type: :string,
          description: "ISO8601 timestamp when timeout expires, or null to remove timeout"
        }
      },
      required: ["guild_id", "user_id", "communication_disabled_until"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timed_out: %{
          type: :boolean,
          description: "Whether the timeout was successfully applied"
        },
        user_id: %{
          type: :string,
          description: "The ID of the timed out user"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        },
        until: %{
          type: :string,
          description: "When the timeout expires (null if removed)"
        }
      },
      required: ["timed_out"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to timeout a member in a guild.

  Returns {:ok, %{timed_out: true, ...}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id) do

      until = Map.get(params, :communication_disabled_until)
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting timeout for user #{user_id} in guild #{guild_id}")

      case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", %{
        json: %{communication_disabled_until: until}
      }) do
        {:ok, _} ->
          Logger.info("Successfully set timeout for user #{user_id} in guild #{guild_id}")
          {:ok, %{timed_out: true, user_id: user_id, guild_id: guild_id, until: until}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to timeout user #{user_id} in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to timeout user #{user_id} in guild #{guild_id}: #{inspect(error)}")
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
