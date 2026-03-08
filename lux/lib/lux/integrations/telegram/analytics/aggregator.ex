defmodule Lux.Integrations.Telegram.Analytics.Aggregator do
  @moduledoc """
  Aggregates raw analytics data into reports and summaries.

  Provides:
  - Performance metrics (avg/p50/p95/p99 response times)
  - Engagement metrics (messages per user, retention)
  - Usage patterns (peak hours, popular commands)
  - Error rate analysis
  """

  alias Lux.Integrations.Telegram.Analytics.Collector

  @doc "Generate a full analytics report."
  def report(collector_pid \\ Collector) do
    with {:ok, counters} <- Collector.get_counters(collector_pid),
         {:ok, events} <- Collector.get_events(collector_pid, %{limit: 10_000}) do
      {:ok, %{
        overview: build_overview(counters),
        performance: build_performance(counters),
        engagement: build_engagement(counters, events),
        errors: build_error_analysis(counters),
        patterns: build_patterns(counters)
      }}
    end
  end

  @doc "Generate performance metrics from response times."
  def performance_metrics(response_times) when is_list(response_times) do
    durations = Enum.map(response_times, fn {_endpoint, ms, _time} -> ms end) |> Enum.sort()

    if length(durations) == 0 do
      %{count: 0, avg: 0.0, p50: 0, p95: 0, p99: 0, min: 0, max: 0}
    else
      count = length(durations)
      %{
        count: count,
        avg: Enum.sum(durations) / count |> Float.round(2),
        p50: percentile(durations, 50),
        p95: percentile(durations, 95),
        p99: percentile(durations, 99),
        min: List.first(durations),
        max: List.last(durations)
      }
    end
  end

  @doc "Calculate error rate as percentage."
  def error_rate(errors_total, messages_total) when messages_total > 0 do
    Float.round(errors_total / messages_total * 100, 2)
  end
  def error_rate(_, _), do: 0.0

  @doc "Calculate messages per user (engagement)."
  def messages_per_user(messages_total, unique_users) when unique_users > 0 do
    Float.round(messages_total / unique_users, 2)
  end
  def messages_per_user(_, _), do: 0.0

  @doc "Find peak usage hours from hourly distribution."
  def peak_hours(hourly_dist) when map_size(hourly_dist) > 0 do
    hourly_dist
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} -> %{hour: hour, messages: count} end)
  end
  def peak_hours(_), do: []

  defp build_overview(counters) do
    %{
      total_messages: counters.messages_total,
      text_messages: counters.messages_text,
      media_messages: counters.messages_media,
      total_commands: counters.commands_total,
      total_errors: counters.errors_total,
      unique_users: counters.unique_users,
      unique_chats: counters.unique_chats,
      uptime_seconds: counters.uptime_seconds,
      error_rate: error_rate(counters.errors_total, counters.messages_total)
    }
  end

  defp build_performance(counters) do
    performance_metrics(counters[:response_times] || [])
  end

  defp build_engagement(counters, _events) do
    %{
      messages_per_user: messages_per_user(counters.messages_total, counters.unique_users),
      messages_per_chat: if(counters.unique_chats > 0, do: Float.round(counters.messages_total / counters.unique_chats, 2), else: 0.0),
      command_usage_rate: if(counters.messages_total > 0, do: Float.round(counters.commands_total / counters.messages_total * 100, 2), else: 0.0)
    }
  end

  defp build_error_analysis(counters) do
    %{
      total: counters.errors_total,
      by_type: counters.errors_by_type,
      rate: error_rate(counters.errors_total, counters.messages_total)
    }
  end

  defp build_patterns(counters) do
    %{
      top_commands: counters.top_commands,
      peak_hours: peak_hours(counters.hourly_distribution)
    }
  end

  defp percentile(sorted_list, p) do
    idx = max(0, round(length(sorted_list) * p / 100) - 1)
    Enum.at(sorted_list, idx, 0)
  end
end
