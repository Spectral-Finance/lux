defmodule Lux.TwitterAnalytics.Aggregator do
  @moduledoc """
  GenServer that aggregates Twitter metrics and provides query interface.

  Receives metrics from MetricsCollector and stores them using Storage module.
  Provides API for reporters and alert managers to query aggregated data.
  """
  use GenServer
  require Logger

  alias Lux.TwitterAnalytics.Storage

  ## Client API

  @doc """
  Start the Aggregator GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a new metric.
  """
  def record_metric(metric) do
    GenServer.cast(__MODULE__, {:record_metric, metric})
  end

  @doc """
  Get metrics for a specific tweet.
  """
  def get_tweet_metrics(tweet_id) do
    GenServer.call(__MODULE__, {:get_tweet_metrics, tweet_id})
  end

  @doc """
  Get metrics within a time range.
  """
  def get_metrics_by_time_range(start_time, end_time) do
    GenServer.call(__MODULE__, {:get_metrics_by_time_range, start_time, end_time})
  end

  @doc """
  Calculate engagement summary for a time period.
  """
  def get_engagement_summary(start_time, end_time) do
    GenServer.call(__MODULE__, {:get_engagement_summary, start_time, end_time})
  end

  @doc """
  Get sentiment distribution for a time period.
  """
  def get_sentiment_distribution(start_time, end_time) do
    GenServer.call(__MODULE__, {:get_sentiment_distribution, start_time, end_time})
  end

  @doc """
  Get hashtag performance.
  """
  def get_hashtag_performance(hashtag, start_time, end_time) do
    GenServer.call(__MODULE__, {:get_hashtag_performance, hashtag, start_time, end_time})
  end

  @doc """
  Get top performing tweets.
  """
  def get_top_tweets(opts \\ []) do
    GenServer.call(__MODULE__, {:get_top_tweets, opts})
  end

  @doc """
  Get storage statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting TwitterAnalytics.Aggregator")
    Storage.init()
    {:ok, %{started_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:record_metric, metric}, state) do
    # Validate and store metric
    metric = ensure_metric_id(metric)
    Storage.store_metric(metric)

    # Update trends if needed
    maybe_update_trends(metric)

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_tweet_metrics, tweet_id}, _from, state) do
    metrics = Storage.list_metrics_by_tweet(tweet_id)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call({:get_metrics_by_time_range, start_time, end_time}, _from, state) do
    metrics = Storage.list_metrics_by_time_range(start_time, end_time)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call({:get_engagement_summary, start_time, end_time}, _from, state) do
    metrics = Storage.list_metrics_by_time_range(start_time, end_time)

    summary = %{
      total_tweets: length(metrics),
      total_likes: sum_metric(metrics, [:metrics, :likes]),
      total_retweets: sum_metric(metrics, [:metrics, :retweets]),
      total_replies: sum_metric(metrics, [:metrics, :replies]),
      total_quotes: sum_metric(metrics, [:metrics, :quotes]),
      period_start: start_time,
      period_end: end_time
    }

    {:reply, {:ok, summary}, state}
  end

  @impl true
  def handle_call({:get_sentiment_distribution, start_time, end_time}, _from, state) do
    metrics = Storage.list_metrics_by_time_range(start_time, end_time)

    distribution =
      metrics
      |> Enum.filter(&(&1.sentiment != nil))
      |> Enum.group_by(& &1.sentiment)
      |> Enum.map(fn {sentiment, items} -> {sentiment, length(items)} end)
      |> Map.new()

    total = Enum.sum(Map.values(distribution))

    result = %{
      distribution: distribution,
      total: total,
      percentages: calculate_percentages(distribution, total)
    }

    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:get_hashtag_performance, hashtag, start_time, end_time}, _from, state) do
    metrics = Storage.list_metrics_by_time_range(start_time, end_time)

    hashtag_metrics =
      metrics
      |> Enum.filter(fn metric ->
        hashtag in (metric.hashtags || [])
      end)

    performance = %{
      hashtag: hashtag,
      tweet_count: length(hashtag_metrics),
      total_engagement: sum_engagement(hashtag_metrics),
      avg_engagement: avg_engagement(hashtag_metrics),
      period_start: start_time,
      period_end: end_time
    }

    {:reply, {:ok, performance}, state}
  end

  @impl true
  def handle_call({:get_top_tweets, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 10)
    start_time = Keyword.get(opts, :start_time)
    end_time = Keyword.get(opts, :end_time)

    metrics =
      if start_time && end_time do
        Storage.list_metrics_by_time_range(start_time, end_time)
      else
        # Get all metrics
        Storage.list_metrics_by_time_range(
          DateTime.add(DateTime.utc_now(), -30, :day),
          DateTime.utc_now()
        )
      end

    top_tweets =
      metrics
      |> Enum.sort_by(&calculate_engagement_score(&1), :desc)
      |> Enum.take(limit)

    {:reply, {:ok, top_tweets}, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = Storage.stats()
    {:reply, {:ok, stats}, state}
  end

  ## Private Functions

  defp ensure_metric_id(metric) do
    if Map.has_key?(metric, :id) do
      metric
    else
      Map.put(metric, :id, generate_id())
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp maybe_update_trends(_metric) do
    # TODO: Implement trend detection and storage
    # For MVP, we'll skip this and focus on real-time metrics
    :ok
  end

  defp sum_metric(metrics, path) do
    metrics
    |> Enum.map(&get_in(&1, path))
    |> Enum.reject(&is_nil/1)
    |> Enum.sum()
  end

  defp sum_engagement(metrics) do
    Enum.reduce(metrics, 0, fn metric, acc ->
      engagement =
        (get_in(metric, [:metrics, :likes]) || 0) +
          (get_in(metric, [:metrics, :retweets]) || 0) +
          (get_in(metric, [:metrics, :replies]) || 0) +
          (get_in(metric, [:metrics, :quotes]) || 0)

      acc + engagement
    end)
  end

  defp avg_engagement([]), do: 0

  defp avg_engagement(metrics) do
    total = sum_engagement(metrics)
    Float.round(total / length(metrics), 2)
  end

  defp calculate_engagement_score(metric) do
    (get_in(metric, [:metrics, :likes]) || 0) +
      (get_in(metric, [:metrics, :retweets]) || 0) * 2 +
      (get_in(metric, [:metrics, :replies]) || 0) * 3 +
      (get_in(metric, [:metrics, :quotes]) || 0) * 4
  end

  defp calculate_percentages(distribution, 0), do: %{}

  defp calculate_percentages(distribution, total) do
    distribution
    |> Enum.map(fn {key, count} ->
      {key, Float.round(count / total * 100, 2)}
    end)
    |> Map.new()
  end
end
