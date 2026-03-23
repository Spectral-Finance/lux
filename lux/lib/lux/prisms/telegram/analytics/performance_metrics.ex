defmodule Lux.Prisms.Telegram.Analytics.PerformanceMetrics do
  @moduledoc """
  A prism for analyzing response time performance from Telegram bot analytics.

  Provides detailed response time statistics including averages, percentiles,
  min/max values, and per-endpoint breakdowns.

  ## Examples

      iex> PerformanceMetrics.handler(%{}, %{name: "Agent"})
      {:ok, %{avg_response_time: 120.5, p50: 100, p95: 250, p99: 500, ...}}
  """

  use Lux.Prism,
    name: "Telegram Performance Metrics",
    description: "Analyzes response time performance from Telegram bot analytics data",
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
        endpoint: %{
          type: :string,
          description: "Optional endpoint to filter response times"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        avg_response_time: %{type: :number, description: "Average response time in ms"},
        p50: %{type: :number, description: "50th percentile response time"},
        p95: %{type: :number, description: "95th percentile response time"},
        p99: %{type: :number, description: "99th percentile response time"},
        min: %{type: :number, description: "Minimum response time"},
        max: %{type: :number, description: "Maximum response time"},
        by_endpoint: %{type: :object, description: "Stats broken down by endpoint"}
      },
      required: ["avg_response_time", "p50", "p95", "p99", "min", "max", "by_endpoint"]
    }

  alias Lux.Integrations.Telegram.Analytics.{Aggregator, Collector}
  require Logger

  @doc """
  Computes performance metrics from collected response time data.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting performance metrics")

    try do
      stats = Collector.get_stats()
      response_times = filter_response_times(stats.response_times, params)
      durations = Enum.map(response_times, & &1.duration_ms)

      by_endpoint = response_times
        |> Enum.group_by(& &1.endpoint)
        |> Enum.map(fn {endpoint, entries} ->
          ep_durations = Enum.map(entries, & &1.duration_ms)
          {endpoint, compute_stats(ep_durations)}
        end)
        |> Enum.into(%{})

      result = Map.merge(compute_stats(durations), %{by_endpoint: by_endpoint})

      {:ok, result}
    rescue
      e ->
        Logger.error("Performance metrics failed: #{inspect(e)}")
        {:error, "Failed to compute performance metrics: #{Exception.message(e)}"}
    end
  end

  defp compute_stats([]) do
    %{avg_response_time: 0.0, p50: 0, p95: 0, p99: 0, min: 0, max: 0}
  end

  defp compute_stats(durations) do
    %{
      avg_response_time: Enum.sum(durations) / length(durations),
      p50: Aggregator.calculate_percentile(durations, 50),
      p95: Aggregator.calculate_percentile(durations, 95),
      p99: Aggregator.calculate_percentile(durations, 99),
      min: Enum.min(durations),
      max: Enum.max(durations)
    }
  end

  defp filter_response_times(response_times, params) do
    response_times
    |> maybe_filter_time_range(params[:time_range])
    |> maybe_filter_endpoint(params[:endpoint])
  end

  defp maybe_filter_time_range(rts, nil), do: rts

  defp maybe_filter_time_range(rts, %{start: start_str, end: end_str}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_str)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_str)

    Enum.filter(rts, fn rt ->
      DateTime.compare(rt.timestamp, start_dt) in [:gt, :eq] and
        DateTime.compare(rt.timestamp, end_dt) in [:lt, :eq]
    end)
  end

  defp maybe_filter_time_range(rts, _), do: rts

  defp maybe_filter_endpoint(rts, nil), do: rts

  defp maybe_filter_endpoint(rts, endpoint) do
    Enum.filter(rts, fn rt -> rt.endpoint == endpoint end)
  end
end
