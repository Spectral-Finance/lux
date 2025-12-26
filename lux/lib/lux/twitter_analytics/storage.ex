defmodule Lux.TwitterAnalytics.Storage do
  @moduledoc """
  ETS-based storage for Twitter analytics data.

  Manages three tables:
  - :twitter_metrics - Individual tweet/user metrics
  - :twitter_trends - Aggregated trend data
  - :twitter_alerts - Triggered alert history
  """

  @metrics_table :twitter_metrics
  @trends_table :twitter_trends
  @alerts_table :twitter_alerts

  @doc """
  Initialize ETS tables for analytics storage.
  """
  def init do
    :ets.new(@metrics_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@trends_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@alerts_table, [:bag, :public, :named_table, read_concurrency: true])
    :ok
  end

  @doc """
  Store a metric record.
  """
  def store_metric(metric) do
    :ets.insert(@metrics_table, {metric.id, metric})
    :ok
  end

  @doc """
  Get a metric by ID.
  """
  def get_metric(id) do
    case :ets.lookup(@metrics_table, id) do
      [{^id, metric}] -> {:ok, metric}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all metrics for a specific tweet.
  """
  def list_metrics_by_tweet(tweet_id) do
    :ets.match_object(@metrics_table, {:_, %{tweet_id: tweet_id}})
    |> Enum.map(fn {_id, metric} -> metric end)
  end

  @doc """
  List metrics within a time range.
  """
  def list_metrics_by_time_range(start_time, end_time) do
    :ets.tab2list(@metrics_table)
    |> Enum.map(fn {_id, metric} -> metric end)
    |> Enum.filter(fn metric ->
      DateTime.compare(metric.timestamp, start_time) in [:gt, :eq] and
        DateTime.compare(metric.timestamp, end_time) in [:lt, :eq]
    end)
  end

  @doc """
  Store a trend record.
  """
  def store_trend(trend) do
    :ets.insert(@trends_table, {trend.id, trend})
    :ok
  end

  @doc """
  Get a trend by ID.
  """
  def get_trend(id) do
    case :ets.lookup(@trends_table, id) do
      [{^id, trend}] -> {:ok, trend}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all trends of a specific type.
  """
  def list_trends_by_type(type) do
    :ets.match_object(@trends_table, {:_, %{type: type}})
    |> Enum.map(fn {_id, trend} -> trend end)
  end

  @doc """
  Store an alert record.
  """
  def store_alert(alert) do
    :ets.insert(@alerts_table, {alert.rule_id, alert})
    :ok
  end

  @doc """
  List all alerts for a specific rule.
  """
  def list_alerts_by_rule(rule_id) do
    :ets.lookup(@alerts_table, rule_id)
    |> Enum.map(fn {_rule_id, alert} -> alert end)
  end

  @doc """
  List all recent alerts within time range.
  """
  def list_recent_alerts(since) do
    :ets.tab2list(@alerts_table)
    |> Enum.map(fn {_rule_id, alert} -> alert end)
    |> Enum.filter(fn alert ->
      DateTime.compare(alert.triggered_at, since) in [:gt, :eq]
    end)
    |> Enum.sort_by(& &1.triggered_at, {:desc, DateTime})
  end

  @doc """
  Clear all data from storage (useful for testing).
  """
  def clear_all do
    :ets.delete_all_objects(@metrics_table)
    :ets.delete_all_objects(@trends_table)
    :ets.delete_all_objects(@alerts_table)
    :ok
  end

  @doc """
  Get storage statistics.
  """
  def stats do
    %{
      metrics_count: :ets.info(@metrics_table, :size),
      trends_count: :ets.info(@trends_table, :size),
      alerts_count: :ets.info(@alerts_table, :size)
    }
  end
end
