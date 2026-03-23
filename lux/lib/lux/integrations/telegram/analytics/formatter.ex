defmodule Lux.Integrations.Telegram.Analytics.Formatter do
  @moduledoc """
  Output formatting module for Telegram bot analytics.

  Provides functions to transform raw analytics data into various output
  formats suitable for dashboards, terminal display, and API responses.

  ## Usage

      stats = Collector.get_stats()

      # Structured map for dashboards
      summary = Formatter.to_summary(stats)

      # ASCII table for terminal display
      table = Formatter.to_ascii_table(stats)

      # JSON-serializable output
      json = Formatter.to_json(stats)
  """

  alias Lux.Integrations.Telegram.Analytics.Aggregator

  @type stats :: %{
          messages: list(map()),
          commands: list(map()),
          errors: list(map()),
          response_times: list(map()),
          custom_metrics: list(map())
        }

  @doc """
  Converts raw stats into a structured summary map suitable for dashboards.

  ## Parameters

    * `stats` - Raw statistics map from the Collector

  ## Returns

  A structured map containing:
    * `:messages` - Message counts and breakdown by type
    * `:commands` - Command usage counts and breakdown
    * `:errors` - Error counts and breakdown by type
    * `:performance` - Response time statistics (avg, p50, p95, p99, min, max)
    * `:custom_metrics` - Custom metric summaries
    * `:generated_at` - Timestamp of report generation
  """
  @spec to_summary(stats()) :: map()
  def to_summary(stats) do
    response_times = extract_durations(stats.response_times)

    %{
      messages: %{
        total: length(stats.messages),
        by_type: Aggregator.group_by_key(stats.messages, :type),
        rate_per_hour: Aggregator.calculate_rate(stats.messages, :per_hour)
      },
      commands: %{
        total: length(stats.commands),
        by_name: Aggregator.group_by_key(stats.commands, :name),
        rate_per_hour: Aggregator.calculate_rate(stats.commands, :per_hour)
      },
      errors: %{
        total: length(stats.errors),
        by_type: Aggregator.group_by_key(stats.errors, :type),
        by_endpoint: Aggregator.group_by_key(stats.errors, :endpoint),
        rate_per_hour: Aggregator.calculate_rate(stats.errors, :per_hour)
      },
      performance: %{
        avg_response_time: safe_avg(response_times),
        p50: Aggregator.calculate_percentile(response_times, 50),
        p95: Aggregator.calculate_percentile(response_times, 95),
        p99: Aggregator.calculate_percentile(response_times, 99),
        min: safe_min(response_times),
        max: safe_max(response_times)
      },
      custom_metrics: summarize_custom_metrics(stats.custom_metrics),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Formats stats as an ASCII table suitable for terminal display.

  ## Parameters

    * `stats` - Raw statistics map from the Collector

  ## Returns

  A string containing a formatted ASCII table.
  """
  @spec to_ascii_table(stats()) :: String.t()
  def to_ascii_table(stats) do
    summary = to_summary(stats)
    response_times = extract_durations(stats.response_times)

    sections = [
      format_header("Telegram Bot Analytics Report"),
      "",
      format_section("Messages", [
        {"Total", summary.messages.total},
        {"Rate (per hour)", Float.round(summary.messages.rate_per_hour, 2)}
      ] ++ format_breakdown(summary.messages.by_type)),
      "",
      format_section("Commands", [
        {"Total", summary.commands.total},
        {"Rate (per hour)", Float.round(summary.commands.rate_per_hour, 2)}
      ] ++ format_breakdown(summary.commands.by_name)),
      "",
      format_section("Errors", [
        {"Total", summary.errors.total},
        {"Rate (per hour)", Float.round(summary.errors.rate_per_hour, 2)}
      ] ++ format_breakdown(summary.errors.by_type)),
      "",
      format_section("Performance", [
        {"Avg Response Time (ms)", safe_round(safe_avg(response_times))},
        {"P50 (ms)", Aggregator.calculate_percentile(response_times, 50)},
        {"P95 (ms)", Aggregator.calculate_percentile(response_times, 95)},
        {"P99 (ms)", Aggregator.calculate_percentile(response_times, 99)},
        {"Min (ms)", safe_min(response_times)},
        {"Max (ms)", safe_max(response_times)}
      ]),
      "",
      format_footer(summary.generated_at)
    ]

    Enum.join(sections, "\n")
  end

  @doc """
  Converts stats into a JSON-serializable map.

  All values are converted to JSON-compatible types (strings, numbers, lists, maps).

  ## Parameters

    * `stats` - Raw statistics map from the Collector

  ## Returns

  A map that can be directly encoded with `Jason.encode/1`.
  """
  @spec to_json(stats()) :: map()
  def to_json(stats) do
    summary = to_summary(stats)

    %{
      "messages" => %{
        "total" => summary.messages.total,
        "by_type" => stringify_keys(summary.messages.by_type),
        "rate_per_hour" => Float.round(summary.messages.rate_per_hour, 4)
      },
      "commands" => %{
        "total" => summary.commands.total,
        "by_name" => stringify_keys(summary.commands.by_name),
        "rate_per_hour" => Float.round(summary.commands.rate_per_hour, 4)
      },
      "errors" => %{
        "total" => summary.errors.total,
        "by_type" => stringify_keys(summary.errors.by_type),
        "by_endpoint" => stringify_keys(summary.errors.by_endpoint),
        "rate_per_hour" => Float.round(summary.errors.rate_per_hour, 4)
      },
      "performance" => %{
        "avg_response_time" => safe_round(summary.performance.avg_response_time),
        "p50" => summary.performance.p50,
        "p95" => summary.performance.p95,
        "p99" => summary.performance.p99,
        "min" => summary.performance.min,
        "max" => summary.performance.max
      },
      "custom_metrics" => stringify_keys(summary.custom_metrics),
      "generated_at" => summary.generated_at
    }
  end

  # Private Helpers

  defp extract_durations(response_times) do
    Enum.map(response_times, fn rt -> rt.duration_ms end)
  end

  defp safe_avg([]), do: 0.0
  defp safe_avg(values), do: Enum.sum(values) / length(values)

  defp safe_min([]), do: 0
  defp safe_min(values), do: Enum.min(values)

  defp safe_max([]), do: 0
  defp safe_max(values), do: Enum.max(values)

  defp safe_round(value) when is_float(value), do: Float.round(value, 2)
  defp safe_round(value), do: value

  defp summarize_custom_metrics(metrics) do
    metrics
    |> Enum.group_by(fn m -> m.metric_name end)
    |> Enum.map(fn {name, entries} ->
      values = Enum.map(entries, fn e -> e.metric_value end)
      {name, %{
        count: length(entries),
        avg: safe_avg(values),
        min: safe_min(values),
        max: safe_max(values)
      }}
    end)
    |> Enum.into(%{})
  end

  defp format_header(title) do
    border = String.duplicate("=", 50)
    "#{border}\n  #{title}\n#{border}"
  end

  defp format_footer(timestamp) do
    border = String.duplicate("-", 50)
    "#{border}\nGenerated at: #{timestamp}"
  end

  defp format_section(title, rows) do
    header = "  #{title}"
    separator = "  " <> String.duplicate("-", 40)

    row_strings = Enum.map(rows, fn {label, value} ->
      "  #{String.pad_trailing(to_string(label), 30)} #{value}"
    end)

    Enum.join([header, separator | row_strings], "\n")
  end

  defp format_breakdown(map) when map == %{}, do: []
  defp format_breakdown(map) do
    Enum.map(map, fn {key, count} ->
      {"  #{key}", count}
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.map(map, fn
      {key, value} when is_map(value) ->
        {to_string(key), stringify_keys(value)}
      {key, value} ->
        {to_string(key), value}
    end)
    |> Enum.into(%{})
  end
end
