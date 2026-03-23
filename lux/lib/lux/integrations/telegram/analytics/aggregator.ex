defmodule Lux.Integrations.Telegram.Analytics.Aggregator do
  @moduledoc """
  Pure-function metric aggregation module for Telegram bot analytics.

  Provides functions to aggregate raw statistics data into meaningful metrics
  including rates, percentiles, and trends. All functions are stateless and
  operate on data snapshots from the Collector.

  ## Usage

      stats = Collector.get_stats()

      # Aggregate by time window
      hourly = Aggregator.aggregate(stats.messages, :hourly)

      # Calculate rates
      rate = Aggregator.calculate_rate(stats.messages, :per_hour)

      # Calculate response time percentiles
      p99 = Aggregator.calculate_percentile(response_times, 99)

      # Detect trends
      trend = Aggregator.calculate_trend(stats.messages, :hourly)
  """

  @type time_window :: :hourly | :daily | :weekly
  @type rate_unit :: :per_minute | :per_hour | :per_day
  @type trend_direction :: :increasing | :decreasing | :stable

  @doc """
  Aggregates a list of events by the specified time window.

  Groups events by their timestamp into buckets corresponding to the
  given time window and returns a map of bucket keys to event counts.

  ## Parameters

    * `events` - List of event maps with `:timestamp` keys
    * `window` - Time window for aggregation: `:hourly`, `:daily`, or `:weekly`

  ## Returns

  A map where keys are time bucket identifiers and values are event counts.
  """
  @spec aggregate(list(map()), time_window()) :: map()
  def aggregate(events, window) when is_list(events) do
    events
    |> Enum.group_by(fn event -> bucket_key(event, window) end)
    |> Enum.map(fn {key, grouped_events} -> {key, length(grouped_events)} end)
    |> Enum.into(%{})
  end

  @doc """
  Calculates the event rate per time unit.

  ## Parameters

    * `events` - List of event maps with `:timestamp` keys
    * `unit` - Rate unit: `:per_minute`, `:per_hour`, or `:per_day`

  ## Returns

  A float representing the average number of events per time unit.
  Returns 0.0 if no events or insufficient time range.
  """
  @spec calculate_rate(list(map()), rate_unit()) :: float()
  def calculate_rate([], _unit), do: 0.0

  def calculate_rate(events, unit) when is_list(events) do
    timestamps =
      events
      |> Enum.map(fn event -> DateTime.to_unix(event.timestamp, :second) end)
      |> Enum.sort()

    min_ts = List.first(timestamps)
    max_ts = List.last(timestamps)

    duration_seconds = max(max_ts - min_ts, 1)
    count = length(events)

    divisor = case unit do
      :per_minute -> duration_seconds / 60
      :per_hour -> duration_seconds / 3600
      :per_day -> duration_seconds / 86_400
    end

    if divisor > 0, do: count / divisor, else: 0.0
  end

  @doc """
  Calculates the specified percentile for a list of numeric values.

  Uses the nearest-rank method for percentile calculation.

  ## Parameters

    * `values` - List of numeric values
    * `percentile` - Percentile to calculate (0-100)

  ## Returns

  The value at the specified percentile, or 0 for empty input.

  ## Examples

      iex> Aggregator.calculate_percentile([10, 20, 30, 40, 50], 50)
      30

      iex> Aggregator.calculate_percentile([10, 20, 30, 40, 50], 99)
      50
  """
  @spec calculate_percentile(list(number()), number()) :: number()
  def calculate_percentile([], _percentile), do: 0

  def calculate_percentile(values, percentile) when is_list(values) and percentile >= 0 and percentile <= 100 do
    sorted = Enum.sort(values)
    count = length(sorted)
    rank = ceil(percentile / 100 * count)
    index = max(rank - 1, 0)

    Enum.at(sorted, min(index, count - 1))
  end

  @doc """
  Calculates the trend direction over successive time windows.

  Compares the event counts across time windows to determine whether
  the metric is increasing, decreasing, or stable.

  ## Parameters

    * `events` - List of event maps with `:timestamp` keys
    * `window` - Time window for comparison: `:hourly`, `:daily`, or `:weekly`

  ## Returns

  A trend direction atom: `:increasing`, `:decreasing`, or `:stable`.
  """
  @spec calculate_trend(list(map()), time_window()) :: trend_direction()
  def calculate_trend([], _window), do: :stable

  def calculate_trend(events, window) when is_list(events) do
    buckets = aggregate(events, window)

    case Map.keys(buckets) |> Enum.sort() do
      keys when length(keys) < 2 ->
        :stable

      keys ->
        values = Enum.map(keys, fn k -> Map.get(buckets, k, 0) end)
        recent = Enum.take(values, -3)

        case recent do
          [a, b] -> compare_values(a, b)
          [a, _b, c] -> compare_values(a, c)
          _ -> :stable
        end
    end
  end

  @doc """
  Identifies peak hours from a list of events.

  Returns a sorted list of {hour, count} tuples representing the busiest
  hours of the day.

  ## Parameters

    * `events` - List of event maps with `:timestamp` keys

  ## Returns

  List of `{hour, count}` tuples sorted by count descending.
  """
  @spec peak_hours(list(map())) :: list({non_neg_integer(), non_neg_integer()})
  def peak_hours(events) when is_list(events) do
    events
    |> Enum.group_by(fn event -> event.timestamp.hour end)
    |> Enum.map(fn {hour, evts} -> {hour, length(evts)} end)
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
  end

  @doc """
  Groups events by a specified key and returns counts.

  ## Parameters

    * `events` - List of event maps
    * `key` - The map key to group by

  ## Returns

  A map of key values to event counts.
  """
  @spec group_by_key(list(map()), atom()) :: map()
  def group_by_key(events, key) when is_list(events) do
    events
    |> Enum.group_by(fn event -> Map.get(event, key) end)
    |> Enum.map(fn {k, evts} -> {k, length(evts)} end)
    |> Enum.into(%{})
  end

  @doc """
  Detects anomalies in event patterns by comparing against the mean.

  An anomaly is a time bucket where the count deviates more than
  2 standard deviations from the mean.

  ## Parameters

    * `events` - List of event maps with `:timestamp` keys
    * `window` - Time window for bucketing

  ## Returns

  A list of `{bucket_key, count}` tuples for anomalous buckets.
  """
  @spec detect_anomalies(list(map()), time_window()) :: list({term(), non_neg_integer()})
  def detect_anomalies([], _window), do: []

  def detect_anomalies(events, window) do
    buckets = aggregate(events, window)
    values = Map.values(buckets)

    mean = Enum.sum(values) / max(length(values), 1)
    variance = Enum.reduce(values, 0, fn v, acc -> acc + (v - mean) ** 2 end) / max(length(values), 1)
    std_dev = :math.sqrt(variance)

    threshold = mean + 2 * std_dev

    buckets
    |> Enum.filter(fn {_key, count} -> count > threshold end)
    |> Enum.sort_by(fn {_key, count} -> count end, :desc)
  end

  # Private Helpers

  defp bucket_key(event, :hourly) do
    ts = event.timestamp
    {ts.year, ts.month, ts.day, ts.hour}
  end

  defp bucket_key(event, :daily) do
    ts = event.timestamp
    {ts.year, ts.month, ts.day}
  end

  defp bucket_key(event, :weekly) do
    ts = event.timestamp
    week = Date.new!(ts.year, ts.month, ts.day) |> Date.day_of_era() |> div(7)
    {ts.year, week}
  end

  defp compare_values(older, newer) do
    cond do
      newer > older -> :increasing
      newer < older -> :decreasing
      true -> :stable
    end
  end
end
