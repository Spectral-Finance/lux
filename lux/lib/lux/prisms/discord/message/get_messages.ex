defmodule Lux.Prisms.Discord.Message.GetMessages do
  @moduledoc """
  A prism for fetching message history from a Discord channel.
  """

  use Lux.Prism,
    name: "Get Discord Messages",
    description: "Fetches message history from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The ID of the channel", pattern: "^[0-9]{17,20}$"},
        limit: %{type: :integer, description: "Max messages to fetch", default: 50, minimum: 1, maximum: 100},
        before: %{type: :string, description: "Get messages before this message ID"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        messages: %{type: :array, description: "List of messages"}
      },
      required: ["messages"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching messages from channel #{channel_id}")

      query = %{limit: params[:limit] || 50}
      query = if params[:before], do: Map.put(query, :before, params[:before]), else: query

      case Client.request(:get, "/channels/#{channel_id}/messages", %{params: query}) do
        {:ok, messages} -> {:ok, %{messages: messages}}
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
