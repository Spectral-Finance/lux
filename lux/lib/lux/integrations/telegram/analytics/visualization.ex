defmodule Lux.Integrations.Telegram.Analytics.Visualization do
  @moduledoc """
  Data visualization helpers for Telegram analytics.

  Provides functions to format analytics data into human-readable
  representations including ASCII charts, tables, and summary reports
  suitable for display in Telegram messages or logs.

  ## Usage

      alias Lux.Integrations.Telegram.Analytics
      alias Lux.Integrations.Telegram.Analytics.Visualization

      # Generate an ASCII bar chart from hourly distribution
      stats = Analytics.get_usage_patterns()
      chart = Visualization.bar_chart(stats.hourly_distribution, title: "Hourly Usage")

      # Generate a summary table
      msg_stats = Analytics.get_message_stats()
      table = Visualization.summary_table(msg_stats)

      # Format a full report
      report = Visualization.full_report(Analytics.get_dashboard())
  """

  @doc """
  Generates an ASCII horizontal bar chart from a map of label => value pairs.

  ## Options

    * `:title` — Chart title (default: `"Chart"`)
    * `:width` — Maximum bar width in characters (default: 30)
    * `:sort` — Sort order: `:asc`, `:desc`, or `:key` (default: `:key`)

  ## Examples

      iex> Visualization.bar_chart(%{0 => 5, 1 => 10, 2 => 3}, title: "Hourly")
      "Hourly\\n──────\\n 0 │ █████░░░░░░░░░░ (5)\\n 1 │ ██████████████░ (10)\\n 2 │ ███░░░░░░░░░░░░ (3)\\n"
  """
  @spec bar_chart(map(), keyword()) :: String.t()
  def bar_chart(data, opts \\ []) when is_map(data) do
    title = Keyword.get(opts, :title, "Chart")
    width = Keyword.get(opts, :width, 30)
    sort = Keyword.get(opts, :sort, :key)

    if map_size(data) == 0 do
      "#{title}\n#{String.duplicate("─", String.length(title))}\nNo data available\n"
    else
      max_val = data |> Map.values() |> Enum.max()

      sorted_entries =
        case sort do
          :asc -> Enum.sort_by(data, fn {_k, v} -> v end, :asc)
          :desc -> Enum.sort_by(data, fn {_k, v} -> v end, :desc)
          :key -> Enum.sort_by(data, fn {k, _v} -> k end)
        end

      max_label_len =
        sorted_entries
        |> Enum.map(fn {k, _v} -> to_string(k) |> String.length() end)
        |> Enum.max(fn -> 1 end)

      bars =
        sorted_entries
        |> Enum.map(fn {label, value} ->
          bar_len = if max_val > 0, do: round(value / max_val * width), else: 0
          empty_len = width - bar_len
          label_str = label |> to_string() |> String.pad_leading(max_label_len)
          bar = String.duplicate("█", bar_len) <> String.duplicate("░", empty_len)
          "#{label_str} │ #{bar} (#{value})"
        end)
        |> Enum.join("\n")

      "#{title}\n#{String.duplicate("─", String.length(title))}\n#{bars}\n"
    end
  end

  @doc """
  Formats a map as a two-column summary table.

  ## Options

    * `:title` — Table title (default: `"Summary"`)

  ## Examples

      iex> Visualization.summary_table(%{total_sent: 100, total_received: 50})
      "Summary\\n═══════\\n  Total Sent      : 100\\n  Total Received  : 50\\n"
  """
  @spec summary_table(map(), keyword()) :: String.t()
  def summary_table(data, opts \\ []) when is_map(data) do
    title = Keyword.get(opts, :title, "Summary")

    if map_size(data) == 0 do
      "#{title}\n#{String.duplicate("═", String.length(title))}\nNo data available\n"
    else
      entries =
        data
        |> Enum.reject(fn {_k, v} -> is_map(v) or is_list(v) end)
        |> Enum.map(fn {key, value} ->
          label = key |> to_string() |> humanize_key()
          {label, format_value(value)}
        end)

      max_label_len =
        entries
        |> Enum.map(fn {label, _v} -> String.length(label) end)
        |> Enum.max(fn -> 1 end)

      rows =
        entries
        |> Enum.map(fn {label, value} ->
          padded_label = String.pad_trailing(label, max_label_len)
          "  #{padded_label} : #{value}"
        end)
        |> Enum.join("\n")

      "#{title}\n#{String.duplicate("═", String.length(title))}\n#{rows}\n"
    end
  end

  @doc """
  Generates a sparkline from a list of numeric values.

  ## Examples

      iex> Visualization.sparkline([1, 3, 5, 2, 8, 4])
      "▁▃▅▂█▄"
  """
  @spec sparkline(list(number())) :: String.t()
  def sparkline([]), do: ""

  def sparkline(values) when is_list(values) do
    chars = ~w(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
    min_val = Enum.min(values)
    max_val = Enum.max(values)
    range = max(max_val - min_val, 1)

    values
    |> Enum.map(fn v ->
      index = round((v - min_val) / range * 7)
      Enum.at(chars, index)
    end)
    |> Enum.join()
  end

  @doc """
  Formats a percentage bar for quick visual representation.

  ## Examples

      iex> Visualization.percentage_bar(75.0, width: 20)
      "███████████████░░░░░ 75.0%"
  """
  @spec percentage_bar(number(), keyword()) :: String.t()
  def percentage_bar(percentage, opts \\ []) do
    width = Keyword.get(opts, :width, 20)
    clamped = max(0, min(100, percentage))
    filled = round(clamped / 100 * width)
    empty = width - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)
    "#{bar} #{Float.round(clamped + 0.0, 1)}%"
  end

  @doc """
  Generates a full analytics report from dashboard data.

  ## Examples

      dashboard = Analytics.get_dashboard()
      report = Visualization.full_report(dashboard)
  """
  @spec full_report(map()) :: String.t()
  def full_report(dashboard) do
    sections = [
      "📊 TELEGRAM BOT ANALYTICS REPORT",
      String.duplicate("═", 40),
      "",
      format_message_section(dashboard[:messages]),
      format_command_section(dashboard[:commands]),
      format_engagement_section(dashboard[:engagement]),
      format_error_section(dashboard[:errors]),
      format_performance_section(dashboard[:performance]),
      format_usage_pattern_section(dashboard[:usage_patterns]),
      "Generated: #{dashboard[:generated_at]}",
      ""
    ]

    Enum.join(sections, "\n")
  end

  @doc """
  Formats a time duration in milliseconds to a human-readable string.

  ## Examples

      iex> Visualization.format_duration(1500)
      "1.5s"

      iex> Visualization.format_duration(42)
      "42ms"
  """
  @spec format_duration(number()) :: String.t()
  def format_duration(ms) when ms < 1000, do: "#{round(ms)}ms"
  def format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  def format_duration(ms) when ms < 3_600_000, do: "#{Float.round(ms / 60_000, 1)}m"
  def format_duration(ms), do: "#{Float.round(ms / 3_600_000, 1)}h"

  # ── Private Formatters ──────────────────────────────────────────────

  defp format_message_section(nil), do: "📨 Messages: No data\n"

  defp format_message_section(stats) do
    [
      "📨 MESSAGE STATISTICS",
      "─────────────────────",
      "  Sent      : #{stats[:total_sent] || 0}",
      "  Received  : #{stats[:total_received] || 0}",
      "  Forwarded : #{stats[:total_forwarded] || 0}",
      "  Edited    : #{stats[:total_edited] || 0}",
      "  Deleted   : #{stats[:total_deleted] || 0}",
      "  Total     : #{stats[:total] || 0}",
      ""
    ]
    |> Enum.join("\n")
  end

  defp format_command_section(nil), do: "🤖 Commands: No data\n"

  defp format_command_section(stats) do
    header = [
      "🤖 COMMAND STATISTICS",
      "─────────────────────",
      "  Total commands: #{stats[:total_commands] || 0}",
      "  Most used: #{stats[:most_used] || "N/A"}",
      ""
    ]

    commands =
      (stats[:commands] || %{})
      |> Enum.map(fn {cmd, info} ->
        rate = percentage_bar(info[:success_rate] || 0, width: 10)
        "  /#{cmd}: #{info[:count] || 0} calls, success: #{rate}"
      end)

    (header ++ commands ++ [""])
    |> Enum.join("\n")
  end

  defp format_engagement_section(nil), do: "👥 Engagement: No data\n"

  defp format_engagement_section(stats) do
    [
      "👥 USER ENGAGEMENT",
      "──────────────────",
      "  Unique users    : #{stats[:total_unique_users] || 0}",
      "  Active (1h)     : #{stats[:active_users_last_hour] || 0}",
      "  Active (24h)    : #{stats[:active_users_last_day] || 0}",
      ""
    ]
    |> Enum.join("\n")
  end

  defp format_error_section(nil), do: "❌ Errors: No data\n"

  defp format_error_section(stats) do
    header = [
      "❌ ERROR MONITORING",
      "───────────────────",
      "  Total errors : #{stats[:total_errors] || 0}",
      "  Error rate   : #{percentage_bar(stats[:error_rate] || 0, width: 10)}",
      ""
    ]

    errors =
      (stats[:errors_by_type] || %{})
      |> Enum.map(fn {type, count} -> "  #{type}: #{count}" end)

    (header ++ errors ++ [""])
    |> Enum.join("\n")
  end

  defp format_performance_section(nil), do: "⚡ Performance: No data\n"

  defp format_performance_section(stats) do
    [
      "⚡ PERFORMANCE METRICS",
      "──────────────────────",
      "  Avg response  : #{format_duration(stats[:avg_response_time_ms] || 0)}",
      "  P50 response  : #{format_duration(stats[:p50_response_time_ms] || 0)}",
      "  P95 response  : #{format_duration(stats[:p95_response_time_ms] || 0)}",
      "  P99 response  : #{format_duration(stats[:p99_response_time_ms] || 0)}",
      "  Min response  : #{format_duration(stats[:min_response_time_ms] || 0)}",
      "  Max response  : #{format_duration(stats[:max_response_time_ms] || 0)}",
      "  Throughput    : #{stats[:throughput_per_minute] || 0} events/min",
      ""
    ]
    |> Enum.join("\n")
  end

  defp format_usage_pattern_section(nil), do: "📈 Usage Patterns: No data\n"

  defp format_usage_pattern_section(stats) do
    hourly =
      if map_size(stats[:hourly_distribution] || %{}) > 0 do
        values =
          0..23
          |> Enum.map(fn h -> Map.get(stats[:hourly_distribution], h, 0) end)

        "  Hourly trend: #{sparkline(values)}"
      else
        "  Hourly trend: No data"
      end

    [
      "📈 USAGE PATTERNS",
      "─────────────────",
      "  Peak hour : #{stats[:peak_hour] || "N/A"}:00",
      "  Peak day  : #{stats[:peak_day] || "N/A"}",
      hourly,
      ""
    ]
    |> Enum.join("\n")
  end

  defp humanize_key(key) do
    key
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_value(value) when is_float(value), do: Float.round(value, 2) |> to_string()
  defp format_value(value), do: to_string(value)
end
