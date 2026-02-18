defmodule Lux.Prisms.Telegram.Analytics.UsagePattern do
  @moduledoc """
  A prism for analyzing Telegram bot usage patterns.

  Provides analysis of usage distribution across hours of day and days of week,
  peak usage detection, and trend identification.

  ## Examples

      # Get usage patterns
      iex> UsagePattern.handler(%{action: "analyze"}, %{name: "Agent"})
      {:ok, %{hourly_distribution: %{...}, daily_distribution: %{...}, peak_hour: 14, peak_day: :wednesday}}
  """

  use Lux.Prism,
    name: "Telegram Usage Pattern Analysis",
    description: "Analyzes Telegram bot usage patterns including hourly and daily distribution",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: 'analyze' to get usage pattern analysis",
          enum: ["analyze"]
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        hourly_distribution: %{type: :object, description: "Event counts per hour (0-23)"},
        daily_distribution: %{type: :object, description: "Event counts per day of week"},
        peak_hour: %{type: :integer, description: "Hour with most activity (0-23)"},
        peak_day: %{type: :string, description: "Day of week with most activity"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles usage pattern analysis.
  """
  def handler(%{action: "analyze"}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} analyzing usage patterns")
    {:ok, Analytics.get_usage_patterns()}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'analyze'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end
end
