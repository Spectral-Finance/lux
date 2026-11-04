defmodule Lux.Beams.Twitter.TwitterAnalyticsPipelineBeam do
  @moduledoc """
  A Beam pipeline coordinating Twitter analytics and monitoring:
  1. Collects and calculates real-time tweet engagement metrics (`CollectMetricsPrism`).
  2. Evaluates sentiment polarity across incoming mentions and replies (`SentimentAnalysisPrism`).
  3. Aggregates hashtag volume, performance, and reach (`HashtagAnalysisPrism`).
  4. Scans for engagement spikes and sentiment anomalies against alert rules (`AlertCheckPrism`).
  5. Formats an executive analytics summary in Markdown and JSON (`GenerateReportPrism`).

  ## Example Usage

  ```elixir
  {:ok, result} = Lux.Beams.Twitter.TwitterAnalyticsPipelineBeam.run(%{
    tweet_id: "189283749281734912",
    mentions: ["Great product!", "Love the new update!", "Bullish on Lux agents"],
    tweets: [
      %{hashtags: ["Lux", "Agent"], impressions: 1200, engagements: 45}
    ]
  })
  ```
  """

  use Lux.Beam,
    name: "Twitter Analytics Pipeline Beam",
    description: "Orchestrates metrics collection, sentiment analysis, hashtag reach, alert auditing, and reporting",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "Primary tweet ID to analyze"},
        mentions: %{type: :array, items: %{type: :string}, description: "Mentions to evaluate"},
        tweets: %{type: :array, description: "Recent tweets for hashtag aggregation"}
      },
      required: ["tweet_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        report_markdown: %{type: :string},
        report_json: %{type: :object},
        success: %{type: :boolean}
      },
      required: ["report_markdown", "success"]
    }

  alias Lux.Prisms.Twitter.Analytics.AlertCheckPrism
  alias Lux.Prisms.Twitter.Analytics.CollectMetricsPrism
  alias Lux.Prisms.Twitter.Analytics.GenerateReportPrism
  alias Lux.Prisms.Twitter.Analytics.HashtagAnalysisPrism
  alias Lux.Prisms.Twitter.Analytics.SentimentAnalysisPrism

  sequence do
    step(:collect_metrics, CollectMetricsPrism, %{
      tweet_id: [:input, :tweet_id]
    })

    step(:analyze_sentiment, SentimentAnalysisPrism, %{
      mentions: [:input, :mentions]
    })

    step(:analyze_hashtags, HashtagAnalysisPrism, %{
      tweets: [:input, :tweets]
    })

    step(:check_alerts, AlertCheckPrism, %{
      metrics: [:steps, :collect_metrics, :result, :metrics],
      sentiment_summary: [:steps, :analyze_sentiment, :result, :sentiment_summary]
    })

    step(:generate_report, GenerateReportPrism, %{
      metrics: [:steps, :collect_metrics, :result, :metrics],
      sentiment_summary: [:steps, :analyze_sentiment, :result, :sentiment_summary],
      hashtag_stats: [:steps, :analyze_hashtags, :result, :hashtag_stats],
      alerts: [:steps, :check_alerts, :result, :alerts]
    })
  end
end
