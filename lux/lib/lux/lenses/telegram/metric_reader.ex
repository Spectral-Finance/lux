defmodule Lux.Lenses.Telegram.MetricReader do
  @moduledoc """
  A lens for reading specific Telegram bot metrics and custom metric values.

  Provides focused access to individual metrics, custom metrics, and
  formatted analytics reports. This lens queries the local analytics
  engine directly rather than making HTTP requests.

  ## Examples

      iex> MetricReader.focus(%{metric: "custom", name: "response_quality"})
      {:ok, %{name: "response_quality", value: 4.5}}

      iex> MetricReader.focus(%{metric: "report"})
      {:ok, %{report: "📊 TELEGRAM BOT ANALYTICS REPORT\\n..."}}

      iex> MetricReader.focus(%{metric: "export"})
      {:ok, %{events: [...], counters: %{...}, ...}}
  """

  alias Lux.Integrations.Telegram.Analytics
  alias Lux.Integrations.Telegram.Analytics.Visualization

  @schema %{
    type: :object,
    properties: %{
      metric: %{
        type: :string,
        description: "Metric to read",
        enum: ["custom", "custom_list", "report", "export"]
      },
      name: %{
        type: :string,
        description: "Custom metric name (required when metric is 'custom')"
      }
    },
    required: ["metric"]
  }

  @doc """
  Returns a lens-like view struct with metadata about this lens.
  """
  @spec view() :: map()
  def view do
    %{
      name: "Telegram Metric Reader",
      description: "Reads specific Telegram bot metrics and custom metric values",
      method: :get,
      schema: @schema
    }
  end

  @doc """
  Focuses the metric reader on a specific metric.

  ## Parameters

    * `input` — Map with `:metric` key and optionally `:name`
    * `opts` — Options (unused, for API compatibility)

  ## Metrics

    * `"custom"` — Read a specific custom metric (requires `:name`)
    * `"custom_list"` — List all defined custom metrics
    * `"report"` — Generate a formatted analytics report
    * `"export"` — Export all analytics data

  ## Examples

      iex> MetricReader.focus(%{metric: "custom", name: "quality"})
      {:ok, %{name: "quality", value: 4.5}}
  """
  @spec focus(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def focus(input \\ %{}, _opts \\ []) do
    metric = Map.get(input, :metric, "custom_list")
    read_metric(metric, input)
  end

  defp read_metric("custom", %{name: name}) when is_binary(name) do
    case Analytics.get_custom_metric(String.to_atom(name)) do
      {:ok, value} -> {:ok, %{name: name, value: value}}
      {:error, :not_found} -> {:error, "Custom metric '#{name}' not found"}
    end
  end

  defp read_metric("custom", _), do: {:error, "Missing 'name' parameter for custom metric"}

  defp read_metric("custom_list", _) do
    {:ok, %{metrics: Analytics.list_custom_metrics()}}
  end

  defp read_metric("report", _) do
    dashboard = Analytics.get_dashboard()
    report = Visualization.full_report(dashboard)
    {:ok, %{report: report}}
  end

  defp read_metric("export", _) do
    {:ok, Analytics.export()}
  end

  defp read_metric(metric, _) do
    {:error, "Unknown metric type: #{metric}"}
  end
end
