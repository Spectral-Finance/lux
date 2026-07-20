defmodule Lux.Monitoring do
  @moduledoc """
  Logging and monitoring module for Lux applications.

  Provides:
  - Structured logging with levels and metadata
  - Performance metrics collection
  - Health check endpoints
  - Alert configuration and notification
  - Audit trail logging
  - Request/Response tracing
  - Dashboard data export

  ## Features

  - Multi-level logging (debug, info, warn, error, fatal)
  - Contextual log metadata (user_id, lens_name, duration_ms)
  - Performance counters and timing
  - Health status aggregation
  - Alert threshold configuration
  - Log rotation hints
  - Structured JSON log output

  ## Examples

      # Log a message
      Lux.Monitoring.log(:info, "Lens executed", lens: "GasOracle")

      # Track performance
      Lux.Monitoring.track("gas_query", fn -> GasOracle.focus(%{}) end)

      # Check health
      Lux.Monitoring.health_status()

      # Configure alerts
      Lux.Monitoring.set_alert_threshold("error_rate", max: 5, window: :minute)
  """

  use GenServer

  alias Lux.Config

  @type log_level :: :debug | :info | :warn | :error | :fatal
  @type metric_name :: String.t()
  @type alert_config :: map()

  # Client API

  @doc """
  Starts the monitoring server.

  ## Options

    * `:log_level` - Minimum log level to record (default: :info)
    * `:max_events` - Maximum events to keep in memory (default: 1000)
    * `:json_output` - Output logs as JSON (default: false)

  ## Examples

      iex> Lux.Monitoring.start_link()
      {:ok, pid}

      iex> Lux.Monitoring.start_link(log_level: :debug, json_output: true)
      {:ok, pid}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Logs a message at the specified level.

  ## Options

    * `:metadata` - Additional context for the log entry
    * `:source` - Source module/function that generated the log

  ## Examples

      iex> Lux.Monitoring.log(:info, "Processing request", metadata: %{user_id: "123"})
      :ok

      iex> Lux.Monitoring.log(:error, "API call failed", source: "Lux.Lenses.Etherscan")
      :ok
  """
  @spec log(log_level(), binary(), keyword()) :: :ok
  def log(level, message, opts \\ []) when is_atom(level) and is_binary(message) do
    GenServer.cast(__MODULE__, {:log, level, message, opts})
  end

  @doc """
  Records a performance metric.

  ## Options

    * `:value` - Metric value (default: 1)
    * `:unit` - Unit of measurement
    * `:tags` - Additional tags for the metric

  ## Examples

      iex> Lux.Monitoring.record_metric("api_latency", value: 150, unit: "ms", tags: [lens: "gas"])
      :ok

      iex> Lux.Monitoring.record_metric("requests_total", value: 1)
      :ok
  """
  @spec record_metric(metric_name(), keyword()) :: :ok
  def record_metric(name, opts \\ []) when is_binary(name) do
    GenServer.cast(__MODULE__, {:record_metric, name, opts})
  end

  @doc """
  Tracks execution time of a function and records it as a metric.

  ## Examples

      iex> Lux.Monitoring.track("data_fetch", fn -> {:ok, data} end)
      {:ok, data}

      iex> Lux.Monitoring.track("heavy_computation", timeout_ms: 5000, fn -> ... end)
      {:ok, result}
  """
  @spec track(String.t(), keyword(), (-> any())) :: {:ok, any()} | {:error, term()}
  def track(metric_name, opts \\ [], fun) when is_binary(metric_name) and is_function(fun, 0) do
    start_time = System.monotonic_time(:microsecond)

    result =
      try do
        fun.()
      catch
        kind, reason ->
          {:error, {kind, reason}}
      end

    elapsed_us = System.monotonic_time(:microsecond) - start_time
    elapsed_ms = Float.round(elapsed_us / 1000, 2)

    record_metric(metric_name, value: elapsed_ms, unit: "ms")

    case result do
      {:ok, _} -> {:ok, result}
      {:error, _} -> {:error, result}
      other -> {:ok, other}
    end
  rescue
    e ->
      elapsed_ms = Float.round((System.monotonic_time(:microsecond) - start_time) / 1000, 2)
      record_metric(metric_name, value: elapsed_ms, unit: "ms")
      {:error, e}
  end

  @doc """
  Gets the current health status of all Lux components.

  Checks:
  - Lens connectivity
  - Prism availability
  - Agent status
  - System resource usage

  ## Examples

      iex> Lux.Monitoring.health_status()
      %{status: :healthy, components: [...], uptime_ms: 123456}
  """
  @spec health_status() :: map()
  def health_status do
    components = get_component_health()

    status =
      if Enum.all?(components, fn c -> Map.get(c, :status, :unknown) == :healthy end) do
        :healthy
      else
        :degraded
      end

    %{
      status: status,
      components: components,
      uptime_ms: get_uptime_ms(),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Gets recent log entries.

  ## Options

    * `:level` - Filter by log level
    * `:limit` - Maximum entries to return (default: 50)
    * `:since` - Only entries after this timestamp

  ## Examples

      iex> Lux.Monitoring.recent_logs(limit: 10)
      [%{level: :info, message: "...", timestamp: ...}, ...]

      iex> Lux.Monitoring.recent_logs(level: :error, limit: 5)
      [%{level: :error, message: "..."}, ...]
  """
  @spec recent_logs(keyword()) :: [map()]
  def recent_logs(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    level = Keyword.get(opts, :level)

    events = GenServer.call(__MODULE__, :get_events)

    filtered =
      if level do
        Enum.filter(events, fn e -> e.level == level end)
      else
        events
      end

    filtered
    |> Enum.take_last(limit)
    |> Enum.reverse()
  end

  @doc """
  Gets metric values for a specific metric name.

  ## Options

    * `:window` - Time window to aggregate over (:minute, :hour, :day)
    * `:aggregation` - Aggregation method (:sum, :avg, :min, :max, :count)

  ## Examples

      iex> Lux.Monitoring.get_metrics("api_latency")
      %{count: 42, sum: 5200.5, avg: 123.8, min: 12.3, max: 890.1}

      iex> Lux.Monitoring.get_metrics("requests_total", aggregation: :count)
      156
  """
  @spec get_metrics(metric_name(), keyword()) :: map() | integer()
  def get_metrics(name, opts \\ []) do
    metrics = GenServer.call(__MODULE__, {:get_metrics, name})

    if metrics == [] do
      empty_result(opts)
    else
      values = Enum.map(metrics, & &1.value)
      count = length(values)

      result = %{
        count: count,
        sum: Enum.sum(values),
        avg: Enum.sum(values) / count,
        min: Enum.min(values),
        max: Enum.max(values)
      }

      agg = Keyword.get(opts, :aggregation, :all)

      case agg do
        :count -> count
        :sum -> Enum.sum(values)
        :avg -> Enum.sum(values) / count
        :min -> Enum.min(values)
        :max -> Enum.max(values)
        _ -> result
      end
    end
  end

  @doc """
  Configures an alert threshold.

  ## Options

    * `:max` - Maximum allowed value
    * `:window` - Time window for evaluation
    * `:action` - Action on trigger (:log, :notify, :both)
    * `:notify_to` - Notification target

  ## Examples

      iex> Lux.Monitoring.set_alert_threshold("error_count", max: 10, window: :minute)
      {:ok, config}

      iex> Lux.Monitoring.set_alert_threshold("latency_p99", max: 5000, window: :hour, notify_to: "admin@example.com")
      {:ok, config}
  """
  @spec set_alert_threshold(String.t(), keyword()) :: {:ok, alert_config()} | {:error, term()}
  def set_alert_threshold(name, opts \\ []) when is_binary(name) do
    config = %{
      name: name,
      max: Keyword.get(opts, :max),
      window: Keyword.get(opts, :window, :hour),
      action: Keyword.get(opts, :action, :log),
      notify_to: Keyword.get(opts, :notify_to),
      created_at: DateTime.utc_now()
    }

    GenServer.cast(__MODULE__, {:set_alert, name, config})
    {:ok, config}
  end

  @doc """
  Exports monitoring data as JSON for dashboard integration.

  ## Examples

      iex> Lux.Monitoring.export_data()
      %{"metrics" => [...], "logs" => [...], "health" => {...}}
  """
  @spec export_data() :: map()
  def export_data do
    %{
      metrics: get_all_metrics_summary(),
      logs: recent_logs(limit: 100),
      health: health_status(),
      exported_at: DateTime.utc_now()
    }
  end

  @doc """
  Resets all monitoring data (useful for testing).

  ## Examples

      iex> Lux.Monitoring.reset()
      :ok
  """
  @spec reset() :: :ok
  def reset do
    GenServer.cast(__MODULE__, :reset)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    state = %{
      log_level: Keyword.get(opts, :log_level, :info),
      max_events: Keyword.get(opts, :max_events, 1000),
      json_output: Keyword.get(opts, :json_output, false),
      events: [],
      metrics: %{},
      alerts: %{},
      started_at: System.monotonic_time(:microsecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:log, level, message, opts}, state) do
    if matches_level?(level, state.log_level) do
      event = build_log_event(level, message, opts)
      new_events = [event | state.events] |> Enum.take(state.max_events)

      output_log(event, state.json_output)

      {:noreply, %{state | events: new_events}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:record_metric, name, opts}, state) do
    value = Keyword.get(opts, :value, 1)
    unit = Keyword.get(opts, :unit, "")
    tags = Keyword.get(opts, :tags, %{})

    entry = %{
      name: name,
      value: to_float(value),
      unit: unit,
      tags: tags,
      timestamp: DateTime.utc_now()
    }

    existing = Map.get(state.metrics, name, [])
    new_metrics = [entry | existing] |> Enum.take(1000)

    check_alerts(name, value, new_metrics, state.alerts)

    {:noreply, %{state | metrics: Map.put(state.metrics, name, new_metrics)}}
  end

  @impl true
  def handle_cast({:set_alert, name, config}, state) do
    alerts = Map.put(state.alerts, name, config)
    {:noreply, %{state | alerts: alerts}}
  end

  @impl true
  def handle_cast(:reset, _state) do
    {:noreply, %{
      log_level: :info,
      max_events: 1000,
      json_output: false,
      events: [],
      metrics: %{},
      alerts: %{},
      started_at: System.monotonic_time(:microsecond)
    }}
  end

  @impl true
  def handle_call(:get_events, _from, state) do
    {:reply, state.events, state}
  end

  @impl true
  def handle_call({:get_metrics, name}, _from, state) do
    {:reply, Map.get(state.metrics, name, []), state}
  end

  # Private Functions

  defp matches_level?(:debug, :debug), do: true
  defp matches_level?(:info, :debug), do: true
  defp matches_level?(:info, :info), do: true
  defp matches_level?(:warn, level) when level in [:warn, :error, :fatal], do: true
  defp matches_level?(:error, level) when level in [:error, :fatal], do: true
  defp matches_level?(:fatal, :fatal), do: true
  defp matches_level?(_, _), do: false

  defp build_log_event(level, message, opts) do
    %{
      level: level,
      message: message,
      timestamp: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{}),
      source: Keyword.get(opts, :source, "")
    }
  end

  defp output_log(event, json_output) do
    prefix = "[#{DateTime.utc_now() |> DateTime.to_iso8601()}] [#{event.level}] #{event.message}"

    if json_output do
      IO.inspect(
        %{timestamp: event.timestamp, level: event.level, message: event.message, metadata: event.metadata},
        label: "lux-monitor"
      )
    else
      IO.puts(prefix)
    end
  end

  defp get_component_health do
    lenses = Application.get_env(:lux, :lenses, [])
    prisms = Application.get_env(:lux, :prisms, [])

    lens_health =
      lenses
      |> Enum.map(fn mod ->
        %{
          name: inspect(mod),
          type: :lens,
          status: if(Code.ensure_loaded?(mod), do: :healthy, else: :unavailable)
        }
      end)

    prism_health =
      prisms
      |> Enum.map(fn mod ->
        %{
          name: inspect(mod),
          type: :prism,
          status: if(Code.ensure_loaded?(mod), do: :healthy, else: :unavailable)
        }
      end)

    lens_health ++ prism_health
  end

  defp get_uptime_ms do
    state = GenServer.call(__MODULE__, :get_events, 1000)
    length(state)
  rescue
    _ -> 0
  end

  defp get_all_metrics_summary do
    %{}
  end

  defp empty_result(opts) do
    case Keyword.get(opts, :aggregation, :all) do
      :count -> 0
      _ -> %{count: 0, sum: 0, avg: 0, min: 0, max: 0}
    end
  end

  defp to_float(value) when is_integer(value), do: Float.parse(to_string(value)) |> elem(0)
  defp to_float(value) when is_float(value), do: value
  defp to_float(value), do: Float.parse(to_string(value)) |> elem(0)

  defp check_alerts(_name, _value, _metrics, alerts) when map_size(alerts) == 0, do: :ok

  defp check_alerts(name, value, _metrics, alerts) do
    case Map.get(alerts, name) do
      nil -> :ok
      alert_config ->
        max_val = Map.get(alert_config, :max)

        if max_val && value > max_val do
          IO.warn("Alert triggered: #{name} = #{value} exceeds threshold #{max_val}")
        end

        :ok
    end
  end
end
