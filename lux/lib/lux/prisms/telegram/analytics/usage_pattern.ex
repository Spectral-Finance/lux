defmodule Lux.Prisms.Telegram.Analytics.UsagePattern do
  @moduledoc """
  A prism for detecting usage patterns from Telegram bot analytics.

  Analyzes temporal patterns in bot usage to identify peak activity hours,
  quiet periods, busiest days, usage trends, and statistical anomalies.

  ## Examples

      iex> UsagePattern.handler(%{granularity: :hourly}, %{name: "Agent"})
      {:ok, %{peak_hours: [14, 15, 16], quiet_hours: [3, 4, 5], ...}}
  """

  use Lux.Prism,
    name: "Telegram Usage Pattern",
    description: "Detects usage patterns from Telegram bot analytics data",
    input_schema: %{
      type: :object,
      properties: %{
        time_range: %{
          type: :object,
          description: "Optional time range filter",
          properties: %{
            start: %{type: :string, description: "ISO 8601 start timestamp"},
            end: %{type: :string, description: "ISO 8601 end timestamp"}
          }
        },
        granularity: %{
          type: :string,
          description: "Analysis granularity: hourly or daily",
          enum: ["hourly", "daily"]
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        peak_hours: %{type: :array, description: "Hours with highest activity"},
        quiet_hours: %{type: :array, description: "Hours with lowest activity"},
        busiest_days: %{type: :array, description: "Days with highest activity"},
        usage_trend: %{type: :string, description: "Overall usage trend direction"},
        anomalies: %{type: :array, description: "Detected anomalous activity periods"}
      },
      required: ["peak_hours", "quiet_hours", "busiest_days", "usage_trend", "anomalies"]
    }

  alias Lux.Integrations.Telegram.Analytics.{Aggregator, Collector}
  require Logger

  @doc """
  Analyzes usage patterns from collected analytics data.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting usage pattern analysis")

    try do
      stats = Collector.get_stats()

      # Combine all events for pattern analysis
      all_events = stats.messages ++ stats.commands
      events = filter_events(all_events, params)

      granularity = parse_granularity(params[:granularity])

      peak_data = Aggregator.peak_hours(events)
      {peak_hours, quiet_hours} = split_peak_quiet(peak_data)

      daily_buckets = Aggregator.aggregate(events, :daily)
      busiest_days = daily_buckets
        |> Enum.sort_by(fn {_day, count} -> count end, :desc)
        |> Enum.take(5)
        |> Enum.map(fn {{year, month, day}, count} ->
          %{date: "#{year}-#{String.pad_leading(to_string(month), 2, "0")}-#{String.pad_leading(to_string(day), 2, "0")}", count: count}
        end)

      result = %{
        peak_hours: peak_hours,
        quiet_hours: quiet_hours,
        busiest_days: busiest_days,
        usage_trend: Aggregator.calculate_trend(events, granularity) |> Atom.to_string(),
        anomalies: Aggregator.detect_anomalies(events, granularity)
          |> Enum.map(fn {bucket, count} -> %{period: inspect(bucket), count: count} end)
      }

      {:ok, result}
    rescue
      e ->
        Logger.error("Usage pattern analysis failed: #{inspect(e)}")
        {:error, "Failed to analyze usage patterns: #{Exception.message(e)}"}
    end
  end

  defp filter_events(events, params) do
    maybe_filter_time_range(events, params[:time_range])
  end

  defp maybe_filter_time_range(events, nil), do: events

  defp maybe_filter_time_range(events, %{start: start_str, end: end_str}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_str)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_str)

    Enum.filter(events, fn evt ->
      DateTime.compare(evt.timestamp, start_dt) in [:gt, :eq] and
        DateTime.compare(evt.timestamp, end_dt) in [:lt, :eq]
    end)
  end

  defp maybe_filter_time_range(events, _), do: events

  defp parse_granularity("daily"), do: :daily
  defp parse_granularity("hourly"), do: :hourly
  defp parse_granularity(_), do: :hourly

  defp split_peak_quiet(peak_data) do
    sorted = Enum.sort_by(peak_data, fn {_hour, count} -> count end, :desc)
    peak_count = min(length(sorted), 5)
    quiet_count = min(length(sorted), 5)

    peak_hours = sorted |> Enum.take(peak_count) |> Enum.map(fn {hour, _} -> hour end)
    quiet_hours = sorted |> Enum.reverse() |> Enum.take(quiet_count) |> Enum.map(fn {hour, _} -> hour end)

    {peak_hours, quiet_hours}
  end
end
