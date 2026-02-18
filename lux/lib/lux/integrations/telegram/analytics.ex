defmodule Lux.Integrations.Telegram.Analytics do
  @moduledoc """
  Core analytics engine for tracking and analyzing Telegram bot usage and performance.

  This module provides an ETS-based storage system for collecting, aggregating,
  and querying Telegram bot metrics. It supports:

  - Message analytics (sent, received, forwarded, edited, deleted)
  - User engagement tracking (active users, session durations, interaction frequency)
  - Command usage statistics (per-command counts, response times, success rates)
  - Error rate monitoring (error counts by type, error trends)
  - Performance metrics (response times, throughput, latency percentiles)
  - Usage pattern analysis (hourly/daily patterns, peak usage detection)
  - Custom metric definitions

  ## Architecture

  The analytics engine uses ETS tables for high-performance concurrent reads:

  - `:telegram_analytics_events` — Raw event log (ordered_set for time-series)
  - `:telegram_analytics_counters` — Atomic counters for metrics
  - `:telegram_analytics_gauges` — Point-in-time gauge values
  - `:telegram_analytics_custom` — User-defined custom metrics

  ## Usage

      # Start the analytics engine
      {:ok, _pid} = Lux.Integrations.Telegram.Analytics.start_link()

      # Record events
      Analytics.record_event(:message_sent, %{chat_id: 123, text: "Hello"})
      Analytics.record_command(:start, %{user_id: 456, response_time_ms: 42})

      # Query metrics
      Analytics.get_message_stats()
      Analytics.get_command_stats()
      Analytics.get_user_engagement()
  """

  use GenServer

  require Logger

  @type event_type ::
          :message_sent
          | :message_received
          | :message_forwarded
          | :message_edited
          | :message_deleted
          | :command_executed
          | :callback_query
          | :inline_query
          | :error
          | :custom

  @type metric_value :: number() | map()

  @type event :: %{
          type: event_type(),
          timestamp: integer(),
          data: map()
        }

  @type time_range :: %{
          from: integer(),
          to: integer()
        }

  @events_table :telegram_analytics_events
  @counters_table :telegram_analytics_counters
  @gauges_table :telegram_analytics_gauges
  @custom_table :telegram_analytics_custom

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts the analytics engine as a linked GenServer process.

  ## Options

    * `:name` — Process name (default: `#{__MODULE__}`)
    * `:max_events` — Maximum events to retain (default: 100_000)
    * `:cleanup_interval_ms` — Interval for cleanup tasks in ms (default: 300_000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a raw analytics event.

  ## Parameters

    * `type` — The event type atom
    * `data` — A map of event-specific data

  ## Examples

      iex> Analytics.record_event(:message_sent, %{chat_id: 123, text: "Hello"})
      :ok
  """
  @spec record_event(event_type(), map()) :: :ok
  def record_event(type, data \\ %{}) do
    timestamp = System.system_time(:millisecond)

    event = %{
      type: type,
      timestamp: timestamp,
      data: data
    }

    :ets.insert(@events_table, {timestamp, event})
    increment_counter(type, 1)
    :ok
  end

  @doc """
  Records a message event with standardized metadata.

  ## Parameters

    * `direction` — `:sent` or `:received`
    * `metadata` — Map with keys like `:chat_id`, `:user_id`, `:message_type`, etc.
  """
  @spec record_message(atom(), map()) :: :ok
  def record_message(direction, metadata \\ %{}) do
    event_type =
      case direction do
        :sent -> :message_sent
        :received -> :message_received
        :forwarded -> :message_forwarded
        :edited -> :message_edited
        :deleted -> :message_deleted
        other -> other
      end

    enriched = Map.merge(metadata, %{direction: direction})
    record_event(event_type, enriched)

    # Track unique user if user_id is present
    if user_id = metadata[:user_id] do
      track_user_activity(user_id)
    end

    :ok
  end

  @doc """
  Records a command execution with timing data.

  ## Parameters

    * `command` — The command name (e.g., `:start`, `:help`)
    * `metadata` — Map with keys like `:user_id`, `:chat_id`, `:response_time_ms`, `:success`
  """
  @spec record_command(atom() | String.t(), map()) :: :ok
  def record_command(command, metadata \\ %{}) do
    command_key = normalize_command(command)

    data =
      metadata
      |> Map.put(:command, command_key)
      |> Map.put_new(:success, true)

    record_event(:command_executed, data)
    increment_counter({:command, command_key}, 1)

    if metadata[:success] == false do
      increment_counter({:command_error, command_key}, 1)
    end

    if response_time = metadata[:response_time_ms] do
      record_response_time(command_key, response_time)
    end

    :ok
  end

  @doc """
  Records an error event.

  ## Parameters

    * `error_type` — The error category (e.g., `:api_error`, `:timeout`, `:validation`)
    * `metadata` — Map with error details
  """
  @spec record_error(atom() | String.t(), map()) :: :ok
  def record_error(error_type, metadata \\ %{}) do
    data = Map.put(metadata, :error_type, error_type)
    record_event(:error, data)
    increment_counter({:error, error_type}, 1)
    increment_counter(:total_errors, 1)
    :ok
  end

  @doc """
  Records a response time measurement for performance tracking.
  """
  @spec record_response_time(atom() | String.t(), number()) :: :ok
  def record_response_time(operation, time_ms) do
    :ets.insert(@gauges_table, {{:response_time, operation, System.system_time(:millisecond)}, time_ms})
    :ok
  end

  @doc """
  Tracks user activity for engagement metrics.
  """
  @spec track_user_activity(integer() | String.t()) :: :ok
  def track_user_activity(user_id) do
    now = System.system_time(:millisecond)
    :ets.insert(@gauges_table, {{:user_activity, user_id}, now})
    increment_counter({:user_messages, user_id}, 1)
    :ok
  end

  @doc """
  Defines a custom metric.

  ## Parameters

    * `name` — Metric name atom
    * `type` — One of `:counter`, `:gauge`, `:histogram`
    * `description` — Human-readable description
  """
  @spec define_custom_metric(atom(), atom(), String.t()) :: :ok
  def define_custom_metric(name, type, description \\ "") do
    :ets.insert(@custom_table, {{:definition, name}, %{type: type, description: description}})
    :ok
  end

  @doc """
  Records a value for a custom metric.
  """
  @spec record_custom_metric(atom(), metric_value()) :: :ok
  def record_custom_metric(name, value) do
    case get_custom_metric_definition(name) do
      nil ->
        Logger.warning("Custom metric #{name} not defined, recording anyway")
        :ets.insert(@custom_table, {{:value, name, System.system_time(:millisecond)}, value})
        :ok

      %{type: :counter} ->
        increment_counter({:custom, name}, value)
        :ok

      %{type: _} ->
        :ets.insert(@custom_table, {{:value, name, System.system_time(:millisecond)}, value})
        :ok
    end
  end

  # ── Query API ───────────────────────────────────────────────────────

  @doc """
  Returns aggregate message statistics.

  ## Returns

      %{
        total_sent: integer(),
        total_received: integer(),
        total_forwarded: integer(),
        total_edited: integer(),
        total_deleted: integer(),
        total: integer()
      }
  """
  @spec get_message_stats() :: map()
  def get_message_stats do
    sent = get_counter(:message_sent)
    received = get_counter(:message_received)
    forwarded = get_counter(:message_forwarded)
    edited = get_counter(:message_edited)
    deleted = get_counter(:message_deleted)

    %{
      total_sent: sent,
      total_received: received,
      total_forwarded: forwarded,
      total_edited: edited,
      total_deleted: deleted,
      total: sent + received + forwarded + edited + deleted
    }
  end

  @doc """
  Returns message statistics for a specific time range.

  ## Parameters

    * `time_range` — Map with `:from` and `:to` timestamps (milliseconds)
  """
  @spec get_message_stats(time_range()) :: map()
  def get_message_stats(%{from: from, to: to}) do
    events = get_events_in_range(from, to)

    message_types = [:message_sent, :message_received, :message_forwarded, :message_edited, :message_deleted]

    counts =
      events
      |> Enum.filter(fn {_ts, evt} -> evt.type in message_types end)
      |> Enum.group_by(fn {_ts, evt} -> evt.type end)
      |> Enum.map(fn {type, evts} -> {type, length(evts)} end)
      |> Map.new()

    %{
      total_sent: Map.get(counts, :message_sent, 0),
      total_received: Map.get(counts, :message_received, 0),
      total_forwarded: Map.get(counts, :message_forwarded, 0),
      total_edited: Map.get(counts, :message_edited, 0),
      total_deleted: Map.get(counts, :message_deleted, 0),
      total:
        Enum.reduce(counts, 0, fn {_type, count}, acc -> acc + count end),
      period: %{from: from, to: to}
    }
  end

  @doc """
  Returns command usage statistics.

  ## Returns

      %{
        commands: %{
          "start" => %{count: 42, error_count: 1, success_rate: 97.6},
          "help" => %{count: 15, error_count: 0, success_rate: 100.0}
        },
        total_commands: integer(),
        most_used: String.t() | nil
      }
  """
  @spec get_command_stats() :: map()
  def get_command_stats do
    # Collect all command counters
    command_entries =
      :ets.match(@counters_table, {{:command, :"$1"}, :"$2"})
      |> Enum.map(fn [cmd, count] -> {cmd, count} end)

    commands =
      command_entries
      |> Enum.map(fn {cmd, count} ->
        error_count = get_counter({:command_error, cmd})
        success_rate = if count > 0, do: Float.round((count - error_count) / count * 100, 1), else: 0.0

        {to_string(cmd),
         %{
           count: count,
           error_count: error_count,
           success_rate: success_rate
         }}
      end)
      |> Map.new()

    total = Enum.reduce(commands, 0, fn {_cmd, %{count: c}}, acc -> acc + c end)

    most_used =
      case Enum.max_by(commands, fn {_cmd, %{count: c}} -> c end, fn -> nil end) do
        nil -> nil
        {cmd, _} -> cmd
      end

    %{
      commands: commands,
      total_commands: total,
      most_used: most_used
    }
  end

  @doc """
  Returns user engagement metrics.

  ## Returns

      %{
        total_unique_users: integer(),
        active_users_last_hour: integer(),
        active_users_last_day: integer(),
        user_message_counts: map(),
        top_users: list()
      }
  """
  @spec get_user_engagement() :: map()
  def get_user_engagement do
    now = System.system_time(:millisecond)
    one_hour_ago = now - 3_600_000
    one_day_ago = now - 86_400_000

    # Get all user activity records
    user_activities =
      :ets.match(@gauges_table, {{:user_activity, :"$1"}, :"$2"})
      |> Enum.map(fn [user_id, last_active] -> {user_id, last_active} end)

    total_unique = length(user_activities)
    active_last_hour = Enum.count(user_activities, fn {_uid, ts} -> ts >= one_hour_ago end)
    active_last_day = Enum.count(user_activities, fn {_uid, ts} -> ts >= one_day_ago end)

    # Get message counts per user
    user_message_counts =
      :ets.match(@counters_table, {{:user_messages, :"$1"}, :"$2"})
      |> Enum.map(fn [user_id, count] -> {user_id, count} end)
      |> Map.new()

    top_users =
      user_message_counts
      |> Enum.sort_by(fn {_uid, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {user_id, count} -> %{user_id: user_id, message_count: count} end)

    %{
      total_unique_users: total_unique,
      active_users_last_hour: active_last_hour,
      active_users_last_day: active_last_day,
      user_message_counts: user_message_counts,
      top_users: top_users
    }
  end

  @doc """
  Returns error monitoring metrics.

  ## Returns

      %{
        total_errors: integer(),
        errors_by_type: map(),
        error_rate: float(),
        recent_errors: list()
      }
  """
  @spec get_error_stats() :: map()
  def get_error_stats do
    total_errors = get_counter(:total_errors)
    total_events = get_total_event_count()

    # Get errors by type
    error_entries =
      :ets.match(@counters_table, {{:error, :"$1"}, :"$2"})
      |> Enum.map(fn [type, count] -> {to_string(type), count} end)
      |> Map.new()

    error_rate =
      if total_events > 0,
        do: Float.round(total_errors / total_events * 100, 2),
        else: 0.0

    # Get recent error events (last 50)
    now = System.system_time(:millisecond)
    one_hour_ago = now - 3_600_000

    recent_errors =
      get_events_in_range(one_hour_ago, now)
      |> Enum.filter(fn {_ts, evt} -> evt.type == :error end)
      |> Enum.take(-50)
      |> Enum.map(fn {_ts, evt} -> evt end)

    %{
      total_errors: total_errors,
      errors_by_type: error_entries,
      error_rate: error_rate,
      recent_errors: recent_errors
    }
  end

  @doc """
  Returns performance metrics including response times and throughput.

  ## Returns

      %{
        avg_response_time_ms: float(),
        p50_response_time_ms: float(),
        p95_response_time_ms: float(),
        p99_response_time_ms: float(),
        min_response_time_ms: float(),
        max_response_time_ms: float(),
        throughput_per_minute: float()
      }
  """
  @spec get_performance_metrics() :: map()
  def get_performance_metrics do
    now = System.system_time(:millisecond)
    five_min_ago = now - 300_000

    # Collect response times from last 5 minutes
    response_times =
      :ets.match(@gauges_table, {{:response_time, :_, :"$1"}, :"$2"})
      |> Enum.filter(fn [ts, _val] -> ts >= five_min_ago end)
      |> Enum.map(fn [_ts, val] -> val end)
      |> Enum.sort()

    case response_times do
      [] ->
        %{
          avg_response_time_ms: 0.0,
          p50_response_time_ms: 0.0,
          p95_response_time_ms: 0.0,
          p99_response_time_ms: 0.0,
          min_response_time_ms: 0.0,
          max_response_time_ms: 0.0,
          throughput_per_minute: 0.0
        }

      times ->
        count = length(times)
        avg = Float.round(Enum.sum(times) / count, 2)

        # Calculate throughput
        total_events = get_total_event_count()
        minutes_elapsed = max((now - five_min_ago) / 60_000, 1)
        throughput = Float.round(total_events / minutes_elapsed, 2)

        %{
          avg_response_time_ms: avg,
          p50_response_time_ms: percentile(times, 50),
          p95_response_time_ms: percentile(times, 95),
          p99_response_time_ms: percentile(times, 99),
          min_response_time_ms: List.first(times) + 0.0,
          max_response_time_ms: List.last(times) + 0.0,
          throughput_per_minute: throughput
        }
    end
  end

  @doc """
  Returns usage patterns broken down by hour of day and day of week.

  ## Returns

      %{
        hourly_distribution: map(),
        daily_distribution: map(),
        peak_hour: integer(),
        peak_day: atom()
      }
  """
  @spec get_usage_patterns() :: map()
  def get_usage_patterns do
    events = :ets.tab2list(@events_table)

    # Build hourly and daily distributions
    {hourly, daily} =
      Enum.reduce(events, {%{}, %{}}, fn {_ts, event}, {hourly_acc, daily_acc} ->
        dt = DateTime.from_unix!(event.timestamp, :millisecond)
        hour = dt.hour
        day = Date.day_of_week(dt) |> day_name()

        hourly_acc = Map.update(hourly_acc, hour, 1, &(&1 + 1))
        daily_acc = Map.update(daily_acc, day, 1, &(&1 + 1))
        {hourly_acc, daily_acc}
      end)

    peak_hour =
      case Enum.max_by(hourly, fn {_h, c} -> c end, fn -> nil end) do
        nil -> 0
        {h, _c} -> h
      end

    peak_day =
      case Enum.max_by(daily, fn {_d, c} -> c end, fn -> nil end) do
        nil -> :monday
        {d, _c} -> d
      end

    %{
      hourly_distribution: hourly,
      daily_distribution: daily,
      peak_hour: peak_hour,
      peak_day: peak_day
    }
  end

  @doc """
  Retrieves the value of a custom metric.
  """
  @spec get_custom_metric(atom()) :: {:ok, term()} | {:error, :not_found}
  def get_custom_metric(name) do
    case get_custom_metric_definition(name) do
      nil ->
        {:error, :not_found}

      %{type: :counter} ->
        {:ok, get_counter({:custom, name})}

      %{type: _} ->
        values =
          :ets.match(@custom_table, {{:value, name, :"$1"}, :"$2"})
          |> Enum.map(fn [ts, val] -> {ts, val} end)
          |> Enum.sort_by(fn {ts, _v} -> ts end)

        case values do
          [] -> {:ok, nil}
          list -> {:ok, List.last(list) |> elem(1)}
        end
    end
  end

  @doc """
  Returns all custom metric definitions.
  """
  @spec list_custom_metrics() :: [map()]
  def list_custom_metrics do
    :ets.match(@custom_table, {{:definition, :"$1"}, :"$2"})
    |> Enum.map(fn [name, definition] -> Map.put(definition, :name, name) end)
  end

  @doc """
  Returns a comprehensive dashboard summary of all analytics.
  """
  @spec get_dashboard() :: map()
  def get_dashboard do
    %{
      messages: get_message_stats(),
      commands: get_command_stats(),
      engagement: get_user_engagement(),
      errors: get_error_stats(),
      performance: get_performance_metrics(),
      usage_patterns: get_usage_patterns(),
      custom_metrics: list_custom_metrics(),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Resets all analytics data. Use with caution.
  """
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@events_table)
    :ets.delete_all_objects(@counters_table)
    :ets.delete_all_objects(@gauges_table)
    :ets.delete_all_objects(@custom_table)
    :ok
  end

  @doc """
  Exports analytics data as a serializable map.
  """
  @spec export() :: map()
  def export do
    %{
      events: :ets.tab2list(@events_table) |> Enum.map(fn {ts, evt} -> %{timestamp: ts, event: evt} end),
      counters: :ets.tab2list(@counters_table) |> Map.new(),
      gauges: :ets.tab2list(@gauges_table) |> Enum.map(fn {key, val} -> %{key: key, value: val} end),
      custom: :ets.tab2list(@custom_table) |> Enum.map(fn {key, val} -> %{key: key, value: val} end),
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # ── Counter Helpers ─────────────────────────────────────────────────

  @doc false
  def increment_counter(key, amount \\ 1) do
    :ets.update_counter(@counters_table, key, {2, amount}, {key, 0})
    :ok
  end

  @doc false
  def get_counter(key) do
    case :ets.lookup(@counters_table, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(opts) do
    max_events = Keyword.get(opts, :max_events, 100_000)
    cleanup_interval = Keyword.get(opts, :cleanup_interval_ms, 300_000)

    # Create ETS tables (safely handle already-existing tables for restarts/tests)
    create_table_if_not_exists(@events_table, [:named_table, :ordered_set, :public, write_concurrency: true, read_concurrency: true])
    create_table_if_not_exists(@counters_table, [:named_table, :set, :public, write_concurrency: true, read_concurrency: true])
    create_table_if_not_exists(@gauges_table, [:named_table, :ordered_set, :public, write_concurrency: true, read_concurrency: true])
    create_table_if_not_exists(@custom_table, [:named_table, :ordered_set, :public, write_concurrency: true, read_concurrency: true])

    # Schedule periodic cleanup
    if cleanup_interval > 0 do
      Process.send_after(self(), :cleanup, cleanup_interval)
    end

    Logger.info("Telegram Analytics engine started")

    {:ok,
     %{
       max_events: max_events,
       cleanup_interval: cleanup_interval
     }}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_events(state.max_events)
    cleanup_old_response_times()
    Process.send_after(self(), :cleanup, state.cleanup_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ── Private Helpers ─────────────────────────────────────────────────

  defp get_events_in_range(from, to) do
    # Use ordered_set property for efficient range queries
    :ets.select(@events_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", from}, {:"=<", :"$1", to}], [{{:"$1", :"$2"}}]}
    ])
  end

  defp get_total_event_count do
    :ets.info(@events_table, :size)
  end

  defp percentile(sorted_list, p) when is_list(sorted_list) and length(sorted_list) > 0 do
    k = (p / 100.0) * (length(sorted_list) - 1)
    f = floor(k)
    c = ceil(k)

    if f == c do
      Enum.at(sorted_list, f) + 0.0
    else
      lower = Enum.at(sorted_list, f)
      upper = Enum.at(sorted_list, c)
      Float.round(lower + (upper - lower) * (k - f), 2)
    end
  end

  defp percentile(_, _), do: 0.0

  defp normalize_command(command) when is_atom(command), do: command
  defp normalize_command("/" <> command), do: String.to_atom(command)
  defp normalize_command(command) when is_binary(command), do: String.to_atom(command)

  defp day_name(1), do: :monday
  defp day_name(2), do: :tuesday
  defp day_name(3), do: :wednesday
  defp day_name(4), do: :thursday
  defp day_name(5), do: :friday
  defp day_name(6), do: :saturday
  defp day_name(7), do: :sunday

  defp get_custom_metric_definition(name) do
    case :ets.lookup(@custom_table, {:definition, name}) do
      [{{:definition, ^name}, definition}] -> definition
      [] -> nil
    end
  end

  defp create_table_if_not_exists(name, opts) do
    case :ets.whereis(name) do
      :undefined -> :ets.new(name, opts)
      _ref -> name
    end
  end

  defp cleanup_old_events(max_events) do
    current_size = :ets.info(@events_table, :size)

    if current_size > max_events do
      excess = current_size - max_events
      keys = :ets.select(@events_table, [{{:"$1", :_}, [], [:"$1"]}]) |> Enum.take(excess)
      Enum.each(keys, fn key -> :ets.delete(@events_table, key) end)
      Logger.debug("Cleaned up #{excess} old analytics events")
    end
  end

  defp cleanup_old_response_times do
    # Keep only last hour of response times
    cutoff = System.system_time(:millisecond) - 3_600_000

    :ets.select_delete(@gauges_table, [
      {{{:response_time, :_, :"$1"}, :_}, [{:<, :"$1", cutoff}], [true]}
    ])
  end
end
