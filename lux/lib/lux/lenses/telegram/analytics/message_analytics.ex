defmodule Lux.Lenses.Telegram.Analytics.MessageAnalytics do
  @moduledoc """
  Lens for analyzing message patterns and content in Telegram chats.

  Retrieves and processes message data from Telegram groups/channels
  to extract engagement patterns, activity heatmaps, and content insights.

  ## Examples

      iex> MessageAnalytics.focus(%{chat_id: "-1001234567890", limit: 100})
      {:ok, %{messages: [...], analytics: %{total: 100, active_users: 45, ...}}}
  """

  use Lux.Lens,
    name: "Telegram Message Analytics",
    description: "Analyzes message patterns, activity distribution, and content engagement in Telegram chats",
    url: "https://api.telegram.org/bot",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Telegram chat ID or @username"
        },
        limit: %{
          type: :integer,
          description: "Number of recent messages to analyze (default: 100, max: 1000)",
          minimum: 1,
          maximum: 1000
        },
        offset: %{
          type: :integer,
          description: "Offset for pagination (default: 0)"
        }
      },
      required: ["chat_id"]
    }

  alias Lux.Integrations.TelegramAnalytics

  def before_focus(params) do
    chat_id = Map.get(params, :chat_id)
    token = TelegramAnalytics.bot_token()

    params
    |> Map.put(:url, "https://api.telegram.org/bot#{token}/getChatHistory")
    |> Map.put(:chat_id, chat_id)
    |> Map.put_new(:limit, 100)
    |> Map.put_new(:offset, 0)
  end

  def after_focus(%{"ok" => true, "result" => messages}) when is_list(messages) do
    analytics = compute_analytics(messages)

    {:ok, %{
      analytics: analytics,
      count: length(messages),
      retrieved_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  end

  def after_focus(%{"ok" => true, "result" => message}) when is_map(message) do
    {:ok, %{
      analytics: compute_analytics([message]),
      count: 1,
      retrieved_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  end

  def after_focus(%{"ok" => false} = error) do
    TelegramAnalytics.parse_error(error)
  end

  def after_focus(body), do: {:ok, body}

  defp compute_analytics(messages) do
    active_users = messages
    |> Enum.map(&Map.get(&1, "from", %{}))
    |> Enum.map(&Map.get(&1, "id"))
    |> Enum.uniq()
    |> length()

    message_types = Enum.reduce(messages, %{}, fn msg, acc ->
      type = cond do
        Map.has_key?(msg, "text") -> "text"
        Map.has_key?(msg, "photo") -> "photo"
        Map.has_key?(msg, "video") -> "video"
        Map.has_key?(msg, "document") -> "document"
        Map.has_key?(msg, "sticker") -> "sticker"
        Map.has_key?(msg, "voice") -> "voice"
        true -> "other"
      end
      Map.update(acc, type, 1, &(&1 + 1))
    end)

    hourly_distribution = messages
    |> Enum.reduce(%{}, fn msg, acc ->
      case Map.get(msg, "date") do
        nil -> acc
        timestamp ->
          hour = DateTime.from_unix!(timestamp).hour
          Map.update(acc, hour, 1, &(&1 + 1))
      end
    end)
    |> Enum.sort_by(fn {hour, _} -> hour end)

    %{
      total_messages: length(messages),
      active_users: active_users,
      message_types: message_types,
      hourly_distribution: hourly_distribution,
      average_message_length: compute_avg_length(messages)
    }
  end

  defp compute_avg_length(messages) do
    text_messages = Enum.filter(messages, &Map.has_key?(&1, "text"))

    if length(text_messages) == 0 do
      0.0
    else
      total = Enum.reduce(text_messages, 0, fn msg, acc ->
        acc + String.length(Map.get(msg, "text", ""))
      end)

      Float.round(total / length(text_messages), 1)
    end
  end
end
