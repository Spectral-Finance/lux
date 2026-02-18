defmodule Lux.Prisms.Telegram.Analytics.MetricAggregation do
  @moduledoc """
  A prism for aggregating and summarizing Telegram bot metrics.

  Provides comprehensive metric aggregation capabilities including
  dashboard summaries, data export, and analytics reset.

  ## Examples

      # Get a full dashboard summary
      iex> MetricAggregation.handler(%{action: "dashboard"}, %{name: "Agent"})
      {:ok, %{messages: %{...}, commands: %{...}, engagement: %{...}, ...}}

      # Export all analytics data
      iex> MetricAggregation.handler(%{action: "export"}, %{name: "Agent"})
      {:ok, %{events: [...], counters: %{...}, ...}}

      # Reset all analytics data
      iex> MetricAggregation.handler(%{action: "reset"}, %{name: "Agent"})
      {:ok, %{reset: true}}
  """

  use Lux.Prism,
    name: "Telegram Metric Aggregation",
    description: "Aggregates and summarizes Telegram bot analytics data",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: 'dashboard' for summary, 'export' for full data, 'reset' to clear all data",
          enum: ["dashboard", "export", "reset"]
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        messages: %{type: :object, description: "Message statistics"},
        commands: %{type: :object, description: "Command statistics"},
        engagement: %{type: :object, description: "User engagement data"},
        errors: %{type: :object, description: "Error statistics"},
        performance: %{type: :object, description: "Performance metrics"},
        usage_patterns: %{type: :object, description: "Usage pattern data"},
        custom_metrics: %{type: :array, description: "Custom metric definitions"},
        generated_at: %{type: :string, description: "Report generation timestamp"},
        reset: %{type: :boolean, description: "Whether data was reset"},
        exported_at: %{type: :string, description: "Export timestamp"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles metric aggregation actions.
  """
  def handler(%{action: "dashboard"}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} generating analytics dashboard")
    {:ok, Analytics.get_dashboard()}
  end

  def handler(%{action: "export"}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} exporting analytics data")
    {:ok, Analytics.export()}
  end

  def handler(%{action: "reset"}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.warning("Agent #{agent_name} resetting all analytics data")
    Analytics.reset()
    {:ok, %{reset: true}}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'dashboard', 'export', or 'reset'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end
end
