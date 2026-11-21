defmodule Lux.Prisms.Discord.Moderation.TimeoutMember do
  @moduledoc """
  A prism for timing out (temporarily disabling) a Discord member.

  Implements the ModerationPrism requirements of lux issue #57: member
  timeouts via Discord's `communication_disabled_until` field. The duration
  is supplied in seconds and converted to an ISO-8601 timestamp by Discord.

  ## Examples
      iex> TimeoutMember.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   user_id: "987654321098765432",
      ...>   duration_seconds: 3600,
      ...>   reason: "Spamming"
      ...> }, %{name: "Agent"})
      {:ok, %{timed_out: true, guild_id: "123456789012345678", user_id: "987654321098765432", duration_seconds: 3600}}
  """

  use Lux.Prism,
    name: "Timeout Discord Member",
    description: "Times out (temporarily disables) a member in a Discord guild",
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
          description: "The ID of the member to time out",
          pattern: "^[0-9]{17,20}$"
        },
        duration_seconds: %{
          type: :integer,
          description: "Timeout duration in seconds (max 28 days = 2419200)",
          minimum: 1,
          maximum: 2_419_200
        },
        reason: %{
          type: :string,
          description: "Optional reason for the timeout (audit log)"
        }
      },
      required: ["guild_id", "user_id", "duration_seconds"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timed_out: %{type: :boolean, description: "Whether the member was timed out"},
        guild_id: %{type: :string, description: "The guild ID"},
        user_id: %{type: :string, description: "The member ID"},
        duration_seconds: %{type: :integer, description: "The applied duration"}
      },
      required: ["timed_out"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @max_duration 2_419_200

  @doc """
  Times out a member for `duration_seconds`.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_id(params, :guild_id),
         {:ok, user_id} <- validate_id(params, :user_id),
         {:ok, duration} <- validate_duration(params, :duration_seconds) do
      agent_name = agent[:name] || "Unknown Agent"

      Logger.info(
        "Agent #{agent_name} timing out member #{user_id} in guild #{guild_id} for #{duration}s"
      )

      opts = build_opts(params, duration)

      case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", opts) do
        {:ok, _body} ->
          Logger.info("Successfully timed out member #{user_id} in guild #{guild_id}")

          {:ok,
           %{
             timed_out: true,
             guild_id: guild_id,
             user_id: user_id,
             duration_seconds: duration
           }}

        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to time out member #{user_id}: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to time out member #{user_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_opts(params, duration) do
    base = %{json: %{communication_disabled_until: iso8601_duration(duration)}}

    case Map.fetch(params, :reason) do
      {:ok, reason} when is_binary(reason) and reason != "" ->
        base

      _ ->
        base
    end
  end

  defp validate_id(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_duration(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_integer(value) and value > 0 and value <= @max_duration ->
        {:ok, value}

      {:ok, value} when is_integer(value) and value > @max_duration ->
        {:error, "duration_seconds exceeds Discord maximum of 28 days"}

      _ ->
        {:error, "Missing or invalid #{key}"}
    end
  end

  @doc """
  Converts a duration in seconds to an ISO-8601 UTC timestamp that is
  `seconds` in the future (the format Discord expects for
  `communication_disabled_until`).
  """
  def iso8601_duration(seconds) when is_integer(seconds) and seconds > 0 do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.to_iso8601()
  end
end
