defmodule Lux.Prisms.Twitter.Analytics.ReportGenerator do
  @moduledoc """
  Generates customizable analytics reports from collected metrics.
  """

  alias Lux.Prisms.Twitter.Analytics.{MetricsCollector, SentimentAnalyzer}

  @doc "Generate a full analytics report."
  def generate(collector_pid, opts \\ %{}) do
    with {:ok, overview} <- MetricsCollector.get_overview(collector_pid),
         {:ok, top_tweets} <- MetricsCollector.get_top_tweets(collector_pid, %{limit: opts[:top_n] || 5}),
         {:ok, hashtags} <- MetricsCollector.get_hashtag_stats(collector_pid),
         {:ok, follower_history} <- MetricsCollector.get_follower_history(collector_pid) do
      {:ok, %{
        overview: overview,
        top_tweets: Enum.map(top_tweets, &Map.take(&1, [:id, :text, :likes, :retweets, :replies, :impressions])),
        top_hashtags: Enum.take(hashtags, 10),
        follower_trend: summarize_follower_trend(follower_history),
        generated_at: DateTime.utc_now()
      }}
    end
  end

  @doc "Generate a sentiment report from mention texts."
  def sentiment_report(texts) do
    batch = SentimentAnalyzer.analyze_batch(texts)
    individual = Enum.map(texts, fn text ->
      %{text: String.slice(text, 0, 100), analysis: SentimentAnalyzer.analyze(text)}
    end)

    {:ok, %{
      summary: batch,
      samples: Enum.take(individual, 20),
      generated_at: DateTime.utc_now()
    }}
  end

  defp summarize_follower_trend(history) do
    case history do
      [] -> %{current: 0, change: 0, snapshots: 0}
      [latest | _] ->
        earliest = List.last(history)
        %{
          current: latest.count,
          change: latest.count - earliest.count,
          snapshots: length(history)
        }
    end
  end
end
