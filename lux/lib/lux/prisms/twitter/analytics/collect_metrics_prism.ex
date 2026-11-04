defmodule Lux.Prisms.Twitter.Analytics.CollectMetricsPrism do
  @moduledoc """
  A prism that collects engagement metrics for a given tweet or account.
  """

  use Lux.Prism,
    name: "Twitter Collect Metrics Prism",
    description: "Gathers tweet impressions, retweets, likes, replies, and calculates engagement rates",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string},
        raw_stats: %{type: :object}
      },
      required: ["tweet_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string},
        engagement_rate: %{type: :number},
        metrics: %{type: :object},
        success: %{type: :boolean}
      },
      required: ["tweet_id", "engagement_rate", "success"]
    }

  alias Lux.Twitter.Analytics.MetricsCollector

  @impl true
  def handler(inputs, _context) do
    tweet_id = Map.get(inputs, "tweet_id") || Map.get(inputs, :tweet_id)
    raw_stats = Map.get(inputs, "raw_stats") || Map.get(inputs, :raw_stats, %{})

    {:ok, metrics} = MetricsCollector.collect_tweet_metrics(tweet_id, raw_stats)

    {:ok,
     %{
       tweet_id: tweet_id,
       engagement_rate: metrics.engagement_rate,
       metrics: metrics,
       success: true
     }}
  end
end
