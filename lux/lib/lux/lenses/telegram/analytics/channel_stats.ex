defmodule Lux.Lenses.Telegram.Analytics.ChannelStats do
  @moduledoc """
  Lens for retrieving detailed channel statistics from the Telegram Bot API.

  Uses the getChatStatistics endpoint to fetch detailed analytics
  including growth metrics, view counts, and engagement data
  for Telegram channels and supergroups.

  Requires the bot to be an administrator in the target chat.

  ## Examples

      iex> ChannelStats.focus(%{chat_id: "-1001234567890"})
      {:ok, %{statistics: %{member_count: 5000, view_count: 50000, ...}}}
  """

  use Lux.Lens,
    name: "Telegram Channel Statistics",
    description: "Retrieves detailed channel/group statistics including growth, views, and engagement metrics",
    url: "https://api.telegram.org/bot",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Telegram chat ID (required, channel/supergroup only)"
        }
      },
      required: ["chat_id"]
    }

  alias Lux.Integrations.TelegramAnalytics

  def before_focus(params) do
    chat_id = Map.get(params, :chat_id)
    token = TelegramAnalytics.bot_token()

    params
    |> Map.put(:url, "https://api.telegram.org/bot#{token}/getChatStatistics")
    |> Map.put(:chat_id, chat_id)
  end

  def after_focus(%{"ok" => true, "result" => stats}) do
    {:ok, %{
      statistics: %{
        member_count: Map.get(stats, "member_count", 0),
        message_count: get_in(stats, ["message_count"]) || get_message_count(stats),
        view_count: get_in(stats, ["view_count"]) || 0,
        daily_active_users: parse_interactions(stats, "day"),
        weekly_active_users: parse_interactions(stats, "week"),
        growth: parse_growth(stats),
        enabled_notifications: Map.get(stats, "enabled_notifications", %{})
      },
      retrieved_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  end

  def after_focus(%{"ok" => false} = error) do
    TelegramAnalytics.parse_error(error)
  end

  def after_focus(body), do: {:ok, body}

  defp parse_interactions(stats, period) do
    stats
    |> Map.get("interactions", %{})
    |> Map.get(period, [])
    |> Enum.map(fn interaction ->
      %{
        date: Map.get(interaction, "date", ""),
        count: Map.get(interaction, "count", 0)
      }
    end)
  end

  defp parse_growth(stats) do
    growth_data = Map.get(stats, "growth", %{})

    %{
      member_count: parse_time_series(growth_data, "member_count"),
      join_count: parse_time_series(growth_data, "join_count"),
      leave_count: parse_time_series(growth_data, "leave_count"),
      enabled_notifications: parse_time_series(growth_data, "enabled_notifications")
    }
  end

  defp parse_time_series(data, key) do
    data
    |> Map.get(key, [])
    |> Enum.map(fn entry ->
      %{
        date: Map.get(entry, "date", ""),
        value: Map.get(entry, "value", 0)
      }
    end)
  end

  defp get_message_count(stats) do
    stats
    |> Map.get("message_count", 0)
  end
end
