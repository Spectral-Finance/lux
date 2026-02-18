defmodule Lux.Prisms.Telegram.Analytics.CustomMetric do
  @moduledoc """
  A prism for defining and recording custom Telegram bot metrics.

  Allows users to define their own metrics with specific types (counter, gauge,
  histogram) and record values against them.

  ## Examples

      # Define a custom metric
      iex> CustomMetric.handler(%{
      ...>   action: "define",
      ...>   name: "response_quality",
      ...>   type: "gauge",
      ...>   description: "User-rated response quality score"
      ...> }, %{name: "Agent"})
      {:ok, %{defined: true, name: "response_quality", type: "gauge"}}

      # Record a custom metric value
      iex> CustomMetric.handler(%{
      ...>   action: "record",
      ...>   name: "response_quality",
      ...>   value: 4.5
      ...> }, %{name: "Agent"})
      {:ok, %{recorded: true, name: "response_quality", value: 4.5}}

      # Get a custom metric value
      iex> CustomMetric.handler(%{
      ...>   action: "get",
      ...>   name: "response_quality"
      ...> }, %{name: "Agent"})
      {:ok, %{name: "response_quality", value: 4.5}}

      # List all custom metrics
      iex> CustomMetric.handler(%{action: "list"}, %{name: "Agent"})
      {:ok, %{metrics: [%{name: :response_quality, type: :gauge, description: "..."}]}}
  """

  use Lux.Prism,
    name: "Telegram Custom Metric",
    description: "Defines, records, and retrieves custom Telegram bot metrics",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: 'define', 'record', 'get', or 'list'",
          enum: ["define", "record", "get", "list"]
        },
        name: %{
          type: :string,
          description: "Metric name (required for define/record/get)"
        },
        type: %{
          type: :string,
          description: "Metric type (required for 'define')",
          enum: ["counter", "gauge", "histogram"]
        },
        description: %{
          type: :string,
          description: "Human-readable metric description (for 'define')"
        },
        value: %{
          type: :number,
          description: "Metric value (required for 'record')"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        defined: %{type: :boolean, description: "Whether the metric was defined"},
        recorded: %{type: :boolean, description: "Whether the value was recorded"},
        name: %{type: :string, description: "Metric name"},
        type: %{type: :string, description: "Metric type"},
        value: %{type: :number, description: "Metric value"},
        metrics: %{type: :array, description: "List of defined metrics"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles custom metric operations.
  """
  def handler(%{action: "define"} = params, agent) do
    with {:ok, name} <- validate_string_param(params, :name),
         {:ok, type} <- validate_metric_type(params) do
      agent_name = agent[:name] || "Unknown Agent"
      description = Map.get(params, :description, "")
      type_atom = String.to_existing_atom(type)

      Logger.info("Agent #{agent_name} defining custom metric: #{name} (#{type})")
      Analytics.define_custom_metric(String.to_atom(name), type_atom, description)

      {:ok, %{defined: true, name: name, type: type}}
    end
  end

  def handler(%{action: "record"} = params, agent) do
    with {:ok, name} <- validate_string_param(params, :name),
         {:ok, value} <- validate_value_param(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} recording custom metric #{name} = #{value}")
      Analytics.record_custom_metric(String.to_atom(name), value)
      {:ok, %{recorded: true, name: name, value: value}}
    end
  end

  def handler(%{action: "get"} = params, _agent) do
    case validate_string_param(params, :name) do
      {:ok, name} ->
        case Analytics.get_custom_metric(String.to_atom(name)) do
          {:ok, value} -> {:ok, %{name: name, value: value}}
          {:error, :not_found} -> {:error, "Custom metric '#{name}' not found"}
        end

      error ->
        error
    end
  end

  def handler(%{action: "list"}, _agent) do
    {:ok, %{metrics: Analytics.list_custom_metrics()}}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'define', 'record', 'get', or 'list'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end

  defp validate_string_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_metric_type(params) do
    case Map.fetch(params, :type) do
      {:ok, type} when type in ["counter", "gauge", "histogram"] -> {:ok, type}
      _ -> {:error, "Missing or invalid type. Must be 'counter', 'gauge', or 'histogram'."}
    end
  end

  defp validate_value_param(params) do
    case Map.fetch(params, :value) do
      {:ok, value} when is_number(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid value (must be a number)"}
    end
  end
end
