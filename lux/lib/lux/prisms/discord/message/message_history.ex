defmodule Lux.Prisms.Discord.Messages.MessageHistory do
  @moduledoc """
  A prism for retrieving message history from a Discord channel.

  ## Examples

      iex> MessageHistory.handler(%{
      ...>   channel_id: "123456789",
      ...>   limit: 50
      ...> }, %{name: "Agent"})
      {:ok, %{
        channel_id: "123456789",
        messages: [%{id: "111", content: "Hello", author: "user1"}],
        total: 50
      }}
  """

  use Lux.Prism,
    name: "Get Discord Message History",
    description: "Retrieves message history from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to retrieve",
          minimum: 1,
          maximum: 100,
          default: 25
        },
        before: %{
          type: :string,
          description: "Message ID to get messages before (for pagination)",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "Message ID to get messages after (for pagination)",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The channel ID"},
        messages: %{type: :array, description: "List of messages with metadata"},
        total: %{type: :integer, description: "Number of messages retrieved"}
      },
      required: ["channel_id", "messages", "total"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, limit} <- validate_optional_param(params, :limit, 25),
         {:ok, before} <- validate_optional_param(params, :before),
         {:ok, after_id} <- validate_optional_param(params, :after) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching message history for channel #{channel_id}")

      query = build_query(limit, before, after_id)

      case Client.request(:get, "/channels/#{channel_id}/messages?#{query}", %{}) do
        {:ok, messages} when is_list(messages) ->
          summaries = Enum.map(messages, &summarize_message/1)
          Logger.info("Retrieved #{length(summaries)} messages from channel #{channel_id}")
          {:ok, %{channel_id: channel_id, messages: summaries, total: length(summaries)}}
        error ->
          Logger.error("Failed to fetch message history: #{inspect(error)}")
          error
      end
    end
  end

  defp build_query(limit, nil, nil), do: "limit=#{limit}"
  defp build_query(limit, before, nil), do: "limit=#{limit}&before=#{before}"
  defp build_query(limit, nil, after_id), do: "limit=#{limit}&after=#{after_id}"
  defp build_query(limit, before, after_id), do: "limit=#{limit}&before=#{before}&after=#{after_id}"

  defp summarize_message(msg) do
    %{
      id: msg["id"],
      content: msg["content"],
      author: get_in(msg, ["author", "username"]),
      author_id: get_in(msg, ["author", "id"]),
      timestamp: msg["timestamp"],
      pinned: msg["pinned"] || false,
      reactions: Enum.map(msg["reactions"] || [], fn r -> %{emoji: r["emoji"]["name"], count: r["count"]} end)
    }
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
