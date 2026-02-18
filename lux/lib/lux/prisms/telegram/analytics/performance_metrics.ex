defmodule Lux.Prisms.Telegram.Analytics.PerformanceMetrics do
  @moduledoc """
  A prism for tracking and analyzing Telegram bot performance metrics.

  Records response times for operations and provides aggregate performance
  statistics including averages, percentiles, throughput, and min/max values.

  ## Examples

      # Record a response time
      iex> PerformanceMetrics.handler(%{
      ...>   action: "record",
      ...>   operation: "send_message",
      ...>   response_time_ms: 142
      ...> }, %{name: "Agent"})
      {:ok, %{recorded: true, operation: "send_message", response_time_ms: 142}}

      # Get performance statistics
      iex> PerformanceMetrics.handler(%{action: "stats"}, %{name: "Agent"})
      {:ok, %{avg_response_time_ms: 85.3, p95_response_time_ms: 250.0, ...}}
  """

  use Lux.Prism,
    name: "Telegram Performance Metrics",
    description: "Tracks and analyzes Telegram bot performance and response times",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: 'record' to log a measurement, 'stats' to retrieve performance data",
          enum: ["record", "stats"]
        },
        operation: %{
          type: :string,
          description: "Operation name (required for 'record' action)"
        },
        response_time_ms: %{
          type: :number,
          description: "Response time in milliseconds (required for 'record' action)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recorded: %{type: :boolean, description: "Whether the measurement was recorded"},
        operation: %{type: :string, description: "The operation name"},
        response_time_ms: %{type: :number, description: "The recorded response time"},
        avg_response_time_ms: %{type: :number, description: "Average response time"},
        p50_response_time_ms: %{type: :number, description: "50th percentile response time"},
        p95_response_time_ms: %{type: :number, description: "95th percentile response time"},
        p99_response_time_ms: %{type: :number, description: "99th percentile response time"},
        min_response_time_ms: %{type: :number, description: "Minimum response time"},
        max_response_time_ms: %{type: :number, description: "Maximum response time"},
        throughput_per_minute: %{type: :number, description: "Events per minute"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles performance metric recording and statistics retrieval.
  """
  def handler(%{action: "record"} = params, agent) do
    with {:ok, operation} <- validate_param(params, :operation),
         {:ok, response_time_ms} <- validate_numeric_param(params, :response_time_ms) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} recording performance: #{operation} = #{response_time_ms}ms")

      Analytics.record_response_time(operation, response_time_ms)
      {:ok, %{recorded: true, operation: operation, response_time_ms: response_time_ms}}
    end
  end

  def handler(%{action: "stats"}, _agent) do
    {:ok, Analytics.get_performance_metrics()}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'record' or 'stats'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_atom(value) and not is_nil(value) -> {:ok, to_string(value)}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_numeric_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_number(value) and value >= 0 -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key} (must be a non-negative number)"}
    end
  end
end
