defmodule Lux.Prisms.Telegram.Analytics.ErrorMonitoring do
  @moduledoc """
  A prism for monitoring error rates and patterns from Telegram bot analytics.

  Tracks error frequency, categorizes errors by type and endpoint, and detects
  error rate trends to help identify reliability issues.

  ## Examples

      iex> ErrorMonitoring.handler(%{}, %{name: "Agent"})
      {:ok, %{total_errors: 15, error_rate: 2.5, errors_by_type: %{timeout: 8, rate_limit: 7}, ...}}
  """

  use Lux.Prism,
    name: "Telegram Error Monitoring",
    description: "Monitors error rates and patterns from Telegram bot analytics data",
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
        error_type: %{
          type: :string,
          description: "Optional error type to filter"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_errors: %{type: :integer, description: "Total number of errors"},
        error_rate: %{type: :number, description: "Errors per hour"},
        errors_by_type: %{type: :object, description: "Error counts grouped by type"},
        errors_by_endpoint: %{type: :object, description: "Error counts grouped by endpoint"},
        error_trend: %{type: :string, description: "Error trend direction"}
      },
      required: ["total_errors", "error_rate", "errors_by_type", "errors_by_endpoint", "error_trend"]
    }

  alias Lux.Integrations.Telegram.Analytics.{Aggregator, Collector}
  require Logger

  @doc """
  Computes error monitoring metrics from collected analytics data.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting error monitoring data")

    try do
      stats = Collector.get_stats()
      errors = filter_errors(stats.errors, params)

      result = %{
        total_errors: length(errors),
        error_rate: Aggregator.calculate_rate(errors, :per_hour),
        errors_by_type: Aggregator.group_by_key(errors, :type),
        errors_by_endpoint: Aggregator.group_by_key(errors, :endpoint),
        error_trend: Aggregator.calculate_trend(errors, :hourly) |> Atom.to_string()
      }

      {:ok, result}
    rescue
      e ->
        Logger.error("Error monitoring failed: #{inspect(e)}")
        {:error, "Failed to compute error monitoring data: #{Exception.message(e)}"}
    end
  end

  defp filter_errors(errors, params) do
    errors
    |> maybe_filter_time_range(params[:time_range])
    |> maybe_filter_error_type(params[:error_type])
  end

  defp maybe_filter_time_range(errors, nil), do: errors

  defp maybe_filter_time_range(errors, %{start: start_str, end: end_str}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_str)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_str)

    Enum.filter(errors, fn err ->
      DateTime.compare(err.timestamp, start_dt) in [:gt, :eq] and
        DateTime.compare(err.timestamp, end_dt) in [:lt, :eq]
    end)
  end

  defp maybe_filter_time_range(errors, _), do: errors

  defp maybe_filter_error_type(errors, nil), do: errors

  defp maybe_filter_error_type(errors, error_type) when is_binary(error_type) do
    Enum.filter(errors, fn err -> Atom.to_string(err.type) == error_type end)
  end

  defp maybe_filter_error_type(errors, error_type) do
    Enum.filter(errors, fn err -> err.type == error_type end)
  end
end
