defmodule Lux.Prisms.Telegram.Analytics.EngagementReport do
  @moduledoc """
  Prism for generating comprehensive engagement reports from Telegram analytics.

  Combines data from multiple Telegram analytics lenses to produce
  actionable engagement reports with growth metrics and activity summaries.

  ## Examples

      iex> EngagementReport.handler(%{chat_id: "-1001234567890"}, ctx)
      {:ok, %{report: %{member_count: 5000, engagement: %{...}, ...}}}
  """

  use Lux.Prism,
    name: "Telegram Engagement Report Generator",
    description: "Generates comprehensive engagement reports combining chat metrics, channel stats, and message analytics",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Telegram chat ID or @username of the group/channel"
        },
        include_message_analytics: %{
          type: :boolean,
          description: "Include message-level analytics in report (default: true)"
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        report: %{
          type: :object,
          properties: %{
            chat_id: %{type: :string},
            member_count: %{type: :integer},
            channel_stats: %{type: :object},
            message_analytics: %{type: :object},
            generated_at: %{type: :string}
          }
        }
      }
    }

  alias Lux.Lenses.Telegram.Analytics.{ChatMetrics, ChannelStats, MessageAnalytics}

  @impl true
  def handler(input, _ctx) do
    chat_id = Map.get(input, :chat_id)

    with {:ok, chat_id} <- validate_chat_id(chat_id),
         {:ok, metrics_data} <- fetch_chat_metrics(chat_id),
         {:ok, stats_data} <- maybe_fetch_channel_stats(chat_id),
         {:ok, message_data} <- maybe_fetch_message_analytics(chat_id, input),
         {:ok, report} <- compile_report(chat_id, metrics_data, stats_data, message_data) do
      {:ok, %{report: report}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_chat_id(nil), do: {:error, "chat_id is required"}
  defp validate_chat_id(id) when is_binary(id) and byte_size(id) > 0, do: {:ok, id}
  defp validate_chat_id(_), do: {:error, "Invalid chat_id"}

  defp fetch_chat_metrics(chat_id) do
    case ChatMetrics.focus(%{chat_id: chat_id}) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, %{member_count: 0}}
    end
  end

  defp maybe_fetch_channel_stats(chat_id) do
    case ChannelStats.focus(%{chat_id: chat_id}) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, nil}
    end
  end

  defp maybe_fetch_message_analytics(chat_id, %{include_message_analytics: false}), do: {:ok, nil}
  defp maybe_fetch_message_analytics(chat_id, _input) do
    case MessageAnalytics.focus(%{chat_id: chat_id, limit: 100}) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, nil}
    end
  end

  defp compile_report(chat_id, metrics_data, stats_data, message_data) do
    {:ok, %{
      chat_id: chat_id,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      member_count: Map.get(metrics_data, :member_count, 0),
      channel_stats: Map.get(stats_data, :statistics),
      message_analytics: Map.get(message_data, :analytics),
      engagement_score: calculate_engagement_score(metrics_data, stats_data, message_data)
    }}
  end

  defp calculate_engagement_score(metrics, stats, messages) do
    member_count = Map.get(metrics, :member_count, 0)
    msg_analytics = Map.get(messages, :analytics, %{})
    active_users = Map.get(msg_analytics, :active_users, 0)

    # Simple engagement score: active_users / member_count * 100
    if member_count > 0 do
      Float.round(active_users / member_count * 100, 2)
    else
      0.0
    end
  end
end
