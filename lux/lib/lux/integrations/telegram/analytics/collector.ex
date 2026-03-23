defmodule Lux.Integrations.Telegram.Analytics.Collector do
  @moduledoc """
  GenServer-based data collector for Telegram bot analytics.

  Uses ETS tables for high-performance storage of metrics data including
  messages, commands, errors, and response times. Automatically prunes
  old data based on a configurable retention period (default 24 hours).

  ## Usage

      # Start the collector
      {:ok, _pid} = Collector.start_link(retention_period: :timer.hours(12))

      # Track events
      Collector.track_message(%{type: :text, chat_id: 123, timestamp: DateTime.utc_now()})
      Collector.track_command(%{name: "/start", user_id: 456, timestamp: DateTime.utc_now()})
      Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: DateTime.utc_now()})
      Collector.track_response_time("/sendMessage", 150)

      # Retrieve stats
      stats = Collector.get_stats()

      # Reset all data
      Collector.reset()
  """

  use GenServer

  require Logger

  @default_retention_period :timer.hours(24)
  @prune_interval :timer.minutes(5)

  @type message_event :: %{
          type: atom(),
          chat_id: integer(),
          timestamp: DateTime.t()
        }

  @type command_event :: %{
          name: String.t(),
          user_id: integer(),
          timestamp: DateTime.t()
        }

  @type error_event :: %{
          type: atom(),
          endpoint: String.t(),
          timestamp: DateTime.t()
        }

  @type stats :: %{
          messages: list(map()),
          commands: list(map()),
          errors: list(map()),
          response_times: list(map()),
          custom_metrics: list(map())
        }

  # Client API

  @doc """
  Starts the analytics collector GenServer.

  ## Options

    * `:retention_period` - Time in milliseconds to retain data (default: 24 hours)
    * `:name` - GenServer name (default: `__MODULE__`)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a message event.

  ## Parameters

    * `event` - Map with `:type`, `:chat_id`, and `:timestamp` keys
  """
  @spec track_message(message_event(), GenServer.server()) :: :ok
  def track_message(event, server \\ __MODULE__) do
    GenServer.cast(server, {:track_message, event})
  end

  @doc """
  Records a command usage event.

  ## Parameters

    * `event` - Map with `:name`, `:user_id`, and `:timestamp` keys
  """
  @spec track_command(command_event(), GenServer.server()) :: :ok
  def track_command(event, server \\ __MODULE__) do
    GenServer.cast(server, {:track_command, event})
  end

  @doc """
  Records an error event.

  ## Parameters

    * `event` - Map with `:type`, `:endpoint`, and `:timestamp` keys
  """
  @spec track_error(error_event(), GenServer.server()) :: :ok
  def track_error(event, server \\ __MODULE__) do
    GenServer.cast(server, {:track_error, event})
  end

  @doc """
  Records a response time measurement.

  ## Parameters

    * `endpoint` - API endpoint path
    * `duration_ms` - Response time in milliseconds
  """
  @spec track_response_time(String.t(), number(), GenServer.server()) :: :ok
  def track_response_time(endpoint, duration_ms, server \\ __MODULE__) do
    GenServer.cast(server, {:track_response_time, endpoint, duration_ms})
  end

  @doc """
  Records a custom metric.

  ## Parameters

    * `metric_name` - Name of the metric
    * `metric_value` - Value of the metric
    * `tags` - Optional tags map
  """
  @spec track_custom_metric(String.t(), number(), map(), GenServer.server()) :: :ok
  def track_custom_metric(metric_name, metric_value, tags \\ %{}, server \\ __MODULE__) do
    GenServer.cast(server, {:track_custom_metric, metric_name, metric_value, tags})
  end

  @doc """
  Returns a snapshot of all currently collected statistics.
  """
  @spec get_stats(GenServer.server()) :: stats()
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  @doc """
  Clears all collected data from the analytics tables.
  """
  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    retention_period = Keyword.get(opts, :retention_period, @default_retention_period)

    tables = %{
      messages: :ets.new(:telegram_analytics_messages, [:bag, :protected]),
      commands: :ets.new(:telegram_analytics_commands, [:bag, :protected]),
      errors: :ets.new(:telegram_analytics_errors, [:bag, :protected]),
      response_times: :ets.new(:telegram_analytics_response_times, [:bag, :protected]),
      custom_metrics: :ets.new(:telegram_analytics_custom_metrics, [:bag, :protected])
    }

    schedule_prune()

    {:ok,
     %{
       tables: tables,
       retention_period: retention_period
     }}
  end

  @impl true
  def handle_cast({:track_message, event}, state) do
    timestamp = Map.get(event, :timestamp, DateTime.utc_now())
    unix_ts = DateTime.to_unix(timestamp, :millisecond)

    :ets.insert(state.tables.messages, {unix_ts, event})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:track_command, event}, state) do
    timestamp = Map.get(event, :timestamp, DateTime.utc_now())
    unix_ts = DateTime.to_unix(timestamp, :millisecond)

    :ets.insert(state.tables.commands, {unix_ts, event})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:track_error, event}, state) do
    timestamp = Map.get(event, :timestamp, DateTime.utc_now())
    unix_ts = DateTime.to_unix(timestamp, :millisecond)

    :ets.insert(state.tables.errors, {unix_ts, event})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:track_response_time, endpoint, duration_ms}, state) do
    now = DateTime.utc_now()
    unix_ts = DateTime.to_unix(now, :millisecond)

    entry = %{endpoint: endpoint, duration_ms: duration_ms, timestamp: now}
    :ets.insert(state.tables.response_times, {unix_ts, entry})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:track_custom_metric, metric_name, metric_value, tags}, state) do
    now = DateTime.utc_now()
    unix_ts = DateTime.to_unix(now, :millisecond)

    entry = %{
      metric_name: metric_name,
      metric_value: metric_value,
      tags: tags,
      timestamp: now,
      metric_id: generate_metric_id()
    }

    :ets.insert(state.tables.custom_metrics, {unix_ts, entry})
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      messages: ets_to_list(state.tables.messages),
      commands: ets_to_list(state.tables.commands),
      errors: ets_to_list(state.tables.errors),
      response_times: ets_to_list(state.tables.response_times),
      custom_metrics: ets_to_list(state.tables.custom_metrics)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Enum.each(state.tables, fn {_name, table} ->
      :ets.delete_all_objects(table)
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:prune, state) do
    prune_old_data(state)
    schedule_prune()
    {:noreply, state}
  end

  # Private Helpers

  defp schedule_prune do
    Process.send_after(self(), :prune, @prune_interval)
  end

  defp prune_old_data(state) do
    cutoff = DateTime.utc_now()
             |> DateTime.add(-state.retention_period, :millisecond)
             |> DateTime.to_unix(:millisecond)

    Enum.each(state.tables, fn {_name, table} ->
      :ets.select_delete(table, [{{:"$1", :_}, [{:<, :"$1", cutoff}], [true]}])
    end)
  end

  defp ets_to_list(table) do
    :ets.tab2list(table)
    |> Enum.map(fn {_ts, event} -> event end)
  end

  defp generate_metric_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
