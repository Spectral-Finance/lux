defmodule Lux.Prisms.Discord.Moderation.TimeoutMember do
  @moduledoc """
  Applies a Discord communication timeout to a guild member.
  """

  use Lux.Prism,
    name: "Timeout Discord Member",
    description: "Applies a communication timeout to a Discord guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "Discord user ID", pattern: "^[0-9]{17,20}$"},
        until_iso8601: %{
          type: :string,
          description: "ISO8601 timestamp when the timeout should end"
        },
        duration_seconds: %{
          type: :integer,
          description: "Timeout duration in seconds when until_iso8601 is omitted",
          minimum: 1
        },
        reason: %{type: :string, description: "Optional Discord audit log reason"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timed_out: %{type: :boolean, description: "Whether the timeout was applied"},
        guild_id: %{type: :string, description: "Discord guild ID"},
        user_id: %{type: :string, description: "Discord user ID"},
        communication_disabled_until: %{type: :string, description: "Timeout end timestamp"}
      },
      required: ["timed_out"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_string(params, :guild_id),
         {:ok, user_id} <- validate_string(params, :user_id),
         {:ok, until_iso8601} <- resolve_until(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} timing out Discord user #{user_id} in guild #{guild_id}")

      opts = %{
        json: %{communication_disabled_until: until_iso8601},
        headers: audit_headers(params[:reason])
      }

      case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", opts) do
        {:ok, _member} ->
          {:ok,
           %{
             timed_out: true,
             guild_id: guild_id,
             user_id: user_id,
             communication_disabled_until: until_iso8601
           }}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp resolve_until(%{until_iso8601: until_iso8601})
       when is_binary(until_iso8601) and until_iso8601 != "" do
    {:ok, until_iso8601}
  end

  defp resolve_until(%{duration_seconds: seconds}) when is_integer(seconds) and seconds > 0 do
    until_iso8601 =
      DateTime.utc_now()
      |> DateTime.add(seconds, :second)
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    {:ok, until_iso8601}
  end

  defp resolve_until(_params), do: {:error, "Missing until_iso8601 or positive duration_seconds"}

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp audit_headers(reason) when is_binary(reason) and reason != "" do
    [{"X-Audit-Log-Reason", URI.encode(reason)}]
  end

  defp audit_headers(_reason), do: []
end
