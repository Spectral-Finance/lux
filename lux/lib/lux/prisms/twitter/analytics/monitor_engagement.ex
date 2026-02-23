defmodule Lux.Prisms.Twitter.Analytics.MonitorEngagement do
  @moduledoc """
  A prism for monitoring tweet engagement against configurable thresholds.

  Evaluates current engagement metrics against defined alert thresholds,
  triggering alerts when metrics exceed or fall below configured limits.
  Enables automated notification when content goes viral or underperforms.

  ## Implementation Details

  - Evaluates metrics against min/max thresholds per metric type
  - Supports: like_count, retweet_count, reply_count, impression_count, engagement_rate
  - Returns all triggered alerts with severity levels
  - Pure computation — no API call required

  ## Examples

      iex> MonitorEngagement.handler(%{
      ...>   metrics: %{like_count: 5000, retweet_count: 1000, impression_count: 100_000},
      ...>   thresholds: %{like_count: %{min: 100, max: 10_000}, retweet_count: %{min: 50}}
      ...> }, %{})
      {:ok, %{
        status: "ok",
        alerts: [],
        metrics_checked: 3
      }}

      iex> MonitorEngagement.handler(%{
      ...>   metrics: %{like_count: 50_000},
      ...>   thresholds: %{like_count: %{max: 10_000}}
      ...> }, %{})
      {:ok, %{
        status: "alert",
        alerts: [%{metric: "like_count", type: "above_max", value: 50000, threshold: 10000, severity: "high"}],
        metrics_checked: 1
      }}
  """

  use Lux.Prism,
    name: "Monitor Twitter Engagement",
    description: "Monitors tweet metrics against configurable thresholds and triggers alerts for viral or underperforming content",
    input_schema: %{
      type: :object,
      properties: %{
        metrics: %{
          type: :object,
          description: "Current engagement metrics to evaluate"
        },
        thresholds: %{
          type: :object,
          description: "Threshold configuration per metric. Each key is a metric name with min/max values.",
          example: "%{like_count: %{min: 100, max: 50000}, engagement_rate: %{min: 1.0}}"
        },
        tweet_id: %{
          type: :string,
          description: "Optional tweet ID for the alert context"
        }
      },
      required: ["metrics", "thresholds"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, description: "ok or alert"},
        alerts: %{type: :array, description: "List of triggered alerts"},
        metrics_checked: %{type: :integer, description: "Number of metrics evaluated"},
        tweet_id: %{type: [:string, :null]}
      }
    }

  @impl true
  def handler(params, _agent) do
    metrics = normalize_map(params[:metrics] || params["metrics"] || %{})
    thresholds = normalize_map(params[:thresholds] || params["thresholds"] || %{})
    tweet_id = params[:tweet_id] || params["tweet_id"]

    alerts =
      thresholds
      |> Enum.flat_map(fn {metric_key, limits} ->
        metric_str = to_string(metric_key)
        current = metrics[metric_str] || metrics[metric_key] || 0
        evaluate_thresholds(metric_str, current, normalize_map(limits))
      end)

    status = if Enum.empty?(alerts), do: "ok", else: "alert"

    {:ok, %{
      status: status,
      alerts: alerts,
      metrics_checked: map_size(thresholds),
      tweet_id: tweet_id
    }}
  end

  defp evaluate_thresholds(metric, value, limits) do
    alerts = []

    alerts =
      case limits["min"] || limits[:min] do
        nil -> alerts
        min when is_number(min) and value < min ->
          [%{
            metric: metric,
            type: "below_min",
            value: value,
            threshold: min,
            severity: severity_for(metric, :low)
          } | alerts]
        _ -> alerts
      end

    alerts =
      case limits["max"] || limits[:max] do
        nil -> alerts
        max when is_number(max) and value > max ->
          [%{
            metric: metric,
            type: "above_max",
            value: value,
            threshold: max,
            severity: severity_for(metric, :high)
          } | alerts]
        _ -> alerts
      end

    alerts
  end

  defp severity_for("impression_count", _), do: "medium"
  defp severity_for("retweet_count", :high), do: "high"
  defp severity_for("like_count", :high), do: "high"
  defp severity_for(_, :high), do: "medium"
  defp severity_for(_, :low), do: "low"

  defp normalize_map(map) when is_map(map), do: map
  defp normalize_map(_), do: %{}
end
