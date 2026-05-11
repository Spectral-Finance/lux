defmodule Lux.Prisms.Discord.Guild.ListChannels do
  @moduledoc """
  A prism for listing channels in a Discord guild.
  """

  use Lux.Prism,
    name: "List Discord Guild Channels",
    description: "Lists all channels in a Discord guild/server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channels: %{type: :array, description: "List of channels"}
      },
      required: ["channels"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} listing channels for guild #{guild_id}")

      case Client.request(:get, "/guilds/#{guild_id}/channels") do
        {:ok, channels} -> {:ok, %{channels: channels}}
        {:error, {status, %{"message" => msg}}} -> {:error, {status, msg}}
        {:error, error} -> {:error, error}
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
