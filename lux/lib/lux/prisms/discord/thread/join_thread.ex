defmodule Lux.Prisms.Discord.Thread.JoinThread do
  @moduledoc """
  A prism for joining a Discord thread.
  """

  use Lux.Prism,
    name: "Join Discord Thread",
    description: "Adds the bot to a Discord thread",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The ID of the thread channel", pattern: "^[0-9]{17,20}$"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean, description: "Whether joining the thread succeeded"}
      },
      required: ["success"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} joining thread #{channel_id}")

      case Client.request(:put, "/channels/#{channel_id}/thread-members/@me") do
        {:ok, _} -> {:ok, %{success: true}}
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
