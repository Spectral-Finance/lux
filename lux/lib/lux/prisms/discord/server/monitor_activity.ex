defmodule Lux.Prisms.Discord.Server.MonitorActivity do
  @moduledoc """
  A prism for monitoring server activity in Discord.

  This prism provides an interface for monitoring Discord server activity with:
  - Required parameters (guild_id)
  - Optional parameters (channel_id, limit)
  - Server activity tracking and reporting
  - Simple success/failure response structure

  ## Examples

      iex> MonitorActivity.handler(%{
      ...>   guild_id: "111111111111111111",
      ...>   limit: 50
      ...> }, %{name: "Agent"})
      {:ok, %{
        guild_id: "111111111111111111",
        activity: %{
          total_messages: 150,
          active_channels: 5,
          top_channels: [%{id: "123", message_count: 50}]
        }
      }}
  """

  use Lux.Prism,
    name: "Monitor Discord Server Activity",
    description: "Monitors activity in a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server to monitor",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "Optional channel ID to monitor specific channel activity",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of recent activities to return",
          minimum: 1,
          maximum: 100,
          default: 25
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the monitored server"
        },
        activity: %{
          type: :object,
          description: "Summary of server activity",
          properties: %{
            total_messages: %{type: :integer},
            active_channels: %{type: :integer},
            top_channels: %{type: :array}
          }
        }
      },
      required: ["guild_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, channel_id} <- validate_optional_param(params, :channel_id),
         {:ok, limit} <- validate_optional_param(params, :limit, 25) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} monitoring activity in server #{guild_id}")

      case fetch_server_activity(guild_id, channel_id, limit) do
        {:ok, activity} ->
          Logger.info("Successfully retrieved activity for server #{guild_id}")
          {:ok, %{guild_id: guild_id, activity: activity}}

        error ->
          Logger.error("Failed to monitor server #{guild_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp fetch_server_activity(guild_id, nil, limit) do
    with {:ok, channels} <- Client.request(:get, "/guilds/#{guild_id}/channels", %{}) do
      active_channels = length(channels)
      channel_summaries = Enum.take(channels, limit)
        |> Enum.map(fn ch -> %{id: ch["id"], name: ch["name"], type: ch["type"]} end)
      {:ok, %{
        total_messages: 0,
        active_channels: active_channels,
        top_channels: channel_summaries
      }}
    end
  end

  defp fetch_server_activity(_guild_id, channel_id, limit) do
    case Client.request(:get, "/channels/#{channel_id}/messages?limit=#{limit}", %{}) do
      {:ok, messages} ->
        {:ok, %{
          total_messages: length(messages),
          active_channels: 1,
          top_channels: [%{id: channel_id, message_count: length(messages)}]
        }}
      error -> error
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end
end
