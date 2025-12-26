defmodule Lux.TwitterAnalytics.AlertManager do
  @moduledoc """
  GenServer for managing alert rules and threshold-based notifications.

  Monitors metrics and triggers alerts when thresholds are breached.
  """
  use GenServer
  require Logger

  alias Lux.TwitterAnalytics.{Aggregator, Storage}

  @check_interval 60 * 1000  # Check every minute

  ## Client API

  @doc """
  Start the AlertManager GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Add an alert rule.

  ## Rule Structure
      %{
        id: "unique_rule_id",          # Optional, auto-generated if not provided
        metric: :likes | :retweets | :replies | :quotes | :engagement | :sentiment,
        threshold: number(),
        comparator: :greater_than | :less_than | :equal | :greater_or_equal | :less_or_equal,
        tweet_id: "optional_tweet_id", # Monitor specific tweet, or nil for all
        action: callback_fn            # Optional callback function
      }
  """
  def add_rule(rule) do
    GenServer.call(__MODULE__, {:add_rule, rule})
  end

  @doc """
  Remove an alert rule.
  """
  def remove_rule(rule_id) do
    GenServer.call(__MODULE__, {:remove_rule, rule_id})
  end

  @doc """
  List all alert rules.
  """
  def list_rules do
    GenServer.call(__MODULE__, :list_rules)
  end

  @doc """
  List recent alerts.
  """
  def list_alerts(opts \\ []) do
    since = Keyword.get(opts, :since, DateTime.add(DateTime.utc_now(), -24, :hour))
    GenServer.call(__MODULE__, {:list_alerts, since})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting TwitterAnalytics.AlertManager")
    # Schedule first check
    schedule_check()

    {:ok, %{rules: %{}}}
  end

  @impl true
  def handle_call({:add_rule, rule}, _from, state) do
    rule = ensure_rule_id(rule)

    if valid_rule?(rule) do
      new_state = put_in(state.rules[rule.id], rule)
      {:reply, {:ok, rule.id}, new_state}
    else
      {:reply, {:error, :invalid_rule}, state}
    end
  end

  @impl true
  def handle_call({:remove_rule, rule_id}, _from, state) do
    new_state = %{state | rules: Map.delete(state.rules, rule_id)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_rules, _from, state) do
    {:reply, {:ok, Map.values(state.rules)}, state}
  end

  @impl true
  def handle_call({:list_alerts, since}, _from, state) do
    alerts = Storage.list_recent_alerts(since)
    {:reply, {:ok, alerts}, state}
  end

  @impl true
  def handle_info(:check_thresholds, state) do
    # Check all rules
    Enum.each(state.rules, fn {_id, rule} ->
      check_rule(rule)
    end)

    # Schedule next check
    schedule_check()

    {:noreply, state}
  end

  ## Private Functions

  defp ensure_rule_id(rule) do
    if Map.has_key?(rule, :id) do
      rule
    else
      Map.put(rule, :id, generate_rule_id())
    end
  end

  defp generate_rule_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp valid_rule?(rule) do
    Map.has_key?(rule, :metric) and
      Map.has_key?(rule, :threshold) and
      Map.has_key?(rule, :comparator) and
      rule.comparator in [:greater_than, :less_than, :equal, :greater_or_equal, :less_or_equal]
  end

  defp schedule_check do
    Process.send_after(self(), :check_thresholds, @check_interval)
  end

  defp check_rule(rule) do
    # Get recent metrics (last 5 minutes)
    start_time = DateTime.add(DateTime.utc_now(), -5, :minute)
    end_time = DateTime.utc_now()

    case Aggregator.get_metrics_by_time_range(start_time, end_time) do
      {:ok, metrics} ->
        filtered_metrics =
          if rule[:tweet_id] do
            Enum.filter(metrics, &(&1.tweet_id == rule.tweet_id))
          else
            metrics
          end

        Enum.each(filtered_metrics, fn metric ->
          check_metric_against_rule(metric, rule)
        end)

      {:error, _reason} ->
        :ok
    end
  end

  defp check_metric_against_rule(metric, rule) do
    actual_value = extract_metric_value(metric, rule.metric)

    if threshold_breached?(actual_value, rule.threshold, rule.comparator) do
      trigger_alert(metric, rule, actual_value)
    end
  end

  defp extract_metric_value(metric, :likes), do: get_in(metric, [:metrics, :likes]) || 0
  defp extract_metric_value(metric, :retweets), do: get_in(metric, [:metrics, :retweets]) || 0
  defp extract_metric_value(metric, :replies), do: get_in(metric, [:metrics, :replies]) || 0
  defp extract_metric_value(metric, :quotes), do: get_in(metric, [:metrics, :quotes]) || 0

  defp extract_metric_value(metric, :engagement) do
    (get_in(metric, [:metrics, :likes]) || 0) +
      (get_in(metric, [:metrics, :retweets]) || 0) +
      (get_in(metric, [:metrics, :replies]) || 0) +
      (get_in(metric, [:metrics, :quotes]) || 0)
  end

  defp extract_metric_value(metric, :sentiment) do
    case metric.sentiment do
      :positive -> 1
      :neutral -> 0
      :negative -> -1
      _ -> 0
    end
  end

  defp threshold_breached?(value, threshold, :greater_than), do: value > threshold
  defp threshold_breached?(value, threshold, :less_than), do: value < threshold
  defp threshold_breached?(value, threshold, :equal), do: value == threshold
  defp threshold_breached?(value, threshold, :greater_or_equal), do: value >= threshold
  defp threshold_breached?(value, threshold, :less_or_equal), do: value <= threshold

  defp trigger_alert(metric, rule, actual_value) do
    alert = %{
      id: generate_alert_id(),
      rule_id: rule.id,
      triggered_at: DateTime.utc_now(),
      metric_type: rule.metric,
      threshold: rule.threshold,
      actual_value: actual_value,
      tweet_id: metric.tweet_id,
      comparator: rule.comparator
    }

    # Store alert
    Storage.store_alert(alert)

    # Log alert
    Logger.info(
      "ALERT: #{rule.metric} #{rule.comparator} #{rule.threshold} (actual: #{actual_value}) for tweet #{metric.tweet_id}"
    )

    # Execute callback if provided
    if rule[:action] && is_function(rule.action) do
      try do
        rule.action.(alert, metric)
      rescue
        error ->
          Logger.error("Alert callback error: #{inspect(error)}")
      end
    end
  end

  defp generate_alert_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
