defmodule Lux.Prisms.Telegram.Analytics.CustomMetrics do
  @moduledoc """
  A prism for recording user-defined custom metrics in Telegram bot analytics.

  Allows tracking arbitrary metrics with optional tags for flexible monitoring
  beyond the built-in analytics categories.

  ## Examples

      iex> CustomMetrics.handler(%{
      ...>   metric_name: "api_latency",
      ...>   metric_value: 150.5,
      ...>   tags: %{region: "us-east"}
      ...> }, %{name: "Agent"})
      {:ok, %{recorded: true, metric_id: "abc123", metric_name: "api_latency"}}
  """

  use Lux.Prism,
    name: "Telegram Custom Metrics",
    description: "Records user-defined custom metrics in Telegram bot analytics",
    input_schema: %{
      type: :object,
      properties: %{
        metric_name: %{
          type: :string,
          description: "Name of the custom metric to record"
        },
        metric_value: %{
          type: :number,
          description: "Numeric value of the metric"
        },
        tags: %{
          type: :object,
          description: "Optional key-value tags for the metric"
        },
        timestamp: %{
          type: :string,
          description: "Optional ISO 8601 timestamp (defaults to current time)"
        }
      },
      required: ["metric_name", "metric_value"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recorded: %{type: :boolean, description: "Whether the metric was successfully recorded"},
        metric_id: %{type: :string, description: "Unique identifier for the recorded metric"},
        metric_name: %{type: :string, description: "Name of the recorded metric"}
      },
      required: ["recorded", "metric_id", "metric_name"]
    }

  alias Lux.Integrations.Telegram.Analytics.Collector
  require Logger

  @doc """
  Records a custom metric via the analytics Collector.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} recording custom metric: #{params.metric_name}")

    with {:ok, metric_name} <- validate_param(params, :metric_name),
         {:ok, metric_value} <- validate_numeric(params, :metric_value) do
      tags = Map.get(params, :tags, %{})
      metric_id = generate_metric_id()

      Collector.track_custom_metric(metric_name, metric_value, tags)

      {:ok, %{
        recorded: true,
        metric_id: metric_id,
        metric_name: metric_name
      }}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_numeric(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_number(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}: must be a number"}
    end
  end

  defp generate_metric_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false)
  end
end
