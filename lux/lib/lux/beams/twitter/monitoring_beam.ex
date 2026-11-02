defmodule Lux.Beams.Twitter.MonitoringBeam do
  @moduledoc """
  An autonomous monitoring beam that aggregates Twitter engagement,
  evaluates public sentiment, checks for spike/risk alert thresholds,
  and synthesizes a complete executive report.
  """

  use Lux.Beam,
    name: "Twitter Monitoring Beam",
    description: "Orchestrates multi-channel Twitter metrics collection, sentiment evaluation, alert triggers, and report synthesis",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{type: :array, description: "List of campaign tweet maps"},
        snapshots: %{type: :array, description: "Historical follower count snapshots"},
        mentions: %{type: :array, description: "Incoming mentions or replies to analyze"},
        thresholds: %{type: :object, description: "Alert thresholds map"},
        handle: %{type: :string, description: "Monitored account handle"}
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        metrics: %{type: :object},
        sentiment: %{type: :object},
        alert_count: %{type: :integer},
        report: %{type: :string}
      },
      required: ["metrics", "sentiment", "report"]
    }

  alias Lux.Prisms.TwitterAnalyticsPrism

  def run(input, _context \\ %{}) do
    tweets = input[:tweets] || input["tweets"] || []
    snapshots = input[:snapshots] || input["snapshots"] || []
    mentions = input[:mentions] || input["mentions"] || []
    thresholds = input[:thresholds] || input["thresholds"] || %{}
    handle = input[:handle] || input["handle"] || "@Spectral_Fi"

    {:ok, %{result: audit_result}} =
      TwitterAnalyticsPrism.run(%{
        action: "run_full_audit",
        payload: %{
          tweets: tweets,
          snapshots: snapshots,
          mentions: mentions,
          thresholds: thresholds,
          report_opts: [handle: handle]
        }
      })

    {:ok,
     %{
       metrics: audit_result.metrics,
       sentiment: audit_result.sentiment,
       growth: audit_result.growth,
       hashtags: audit_result.hashtags,
       alerts: audit_result.alerts,
       alert_count: length(audit_result.alerts),
       report: audit_result.report
     }}
  end
end
