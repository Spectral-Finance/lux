defmodule Lux.Beams.Telegram.AnalyticsBeam do
  @moduledoc """
  A beam pipeline for end-to-end Telegram analytics, health monitoring,
  and visual reporting:
  1. Aggregates volume, user engagement, and command statistics
  2. Measures latency percentiles and error rate anomalies
  3. Identifies peak hours and community usage patterns
  4. Generates executive reports with ASCII data visualization
  """

  use Lux.Beam,
    name: "Telegram Analytics & Monitoring Pipeline",
    description: "Orchestrates Telegram metrics aggregation, health monitoring, and report generation",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Telemetry events list"},
        format: %{type: :string, description: "Report format: 'markdown' or 'html'"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        metrics: %{type: :object},
        performance: %{type: :object},
        patterns: %{type: :object},
        report: %{type: :object}
      },
      required: ["metrics", "performance", "report"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Telegram.Analytics.AggregateMetrics
  alias Lux.Prisms.Telegram.Analytics.TrackPerformance
  alias Lux.Prisms.Telegram.Analytics.AnalyzeUsagePatterns
  alias Lux.Prisms.Telegram.Analytics.GenerateReport

  sequence do
    # 1. Aggregate volume, engagement, commands
    step(:metrics, AggregateMetrics, %{
      events: [:input, :events]
    })

    # 2. Track performance & detect alerts
    step(:performance, TrackPerformance, %{
      events: [:input, :events]
    })

    # 3. Analyze temporal usage patterns
    step(:patterns, AnalyzeUsagePatterns, %{
      events: [:input, :events]
    })

    # 4. Generate visual report
    step(:report, GenerateReport, %{
      analytics: %{
        messages: [:steps, :metrics, :result, :messages],
        engagement: [:steps, :metrics, :result, :engagement],
        commands: [:steps, :metrics, :result, :commands],
        performance: [:steps, :performance, :result]
      },
      format: [:input, :format]
    })
  end

  @doc """
  Direct execution helper for generating full analytics over an events list.
  """
  def analyze_events(events, opts \\ []) do
    format = Keyword.get(opts, :format, "markdown")

    with {:ok, metrics} <- AggregateMetrics.handler(%{events: events}, %{}),
         {:ok, perf} <- TrackPerformance.handler(%{events: events}, %{}),
         {:ok, patterns} <- AnalyzeUsagePatterns.handler(%{events: events}, %{}) do
      combined = %{
        messages: metrics.messages,
        engagement: metrics.engagement,
        commands: metrics.commands,
        performance: perf
      }

      {:ok, report} = GenerateReport.handler(%{analytics: combined, format: format}, %{})

      {:ok,
       %{
         metrics: metrics,
         performance: perf,
         patterns: patterns,
         report: report
       }}
    end
  end
end
