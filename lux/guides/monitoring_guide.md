# Monitoring and Observability Guide

Comprehensive guide to monitoring, logging, alerting, and debugging Lux-based agent systems in production.

## Observability Architecture

Lux provides three layers of observability:

```
┌─────────────────────────────────────────────┐
│              ALERTING LAYER                  │
│  Prometheus, Datadog, Grafana, PagerDuty     │
├─────────────────────────────────────────────┤
│             TELEMETRY LAYER                  │
│  [:lux, :agent, ...], [:lux, :beam, ...]   │
├─────────────────────────────────────────────┤
│              LOGGING LAYER                   │
│  Structured JSON, Agent Context, Beam Logs  │
└─────────────────────────────────────────────┘
```

## Structured Logging

### JSON Logging Configuration

```elixir
# config/prod.exs
config :logger, :console,
  format: {Lux.Logging.JSONFormatter, :format},
  metadata: [:agent_id, :beam_id, :request_id, :company_id, :signal_id],
  level: :info
```

### Log Levels

| Level | Use When |
|-------|----------|
| `:debug` | Development troubleshooting, step-by-step flow |
| `:info` | Normal operations: agent start/stop, beam completion |
| `:warning` | Retryable errors, rate limits, degraded services |
| `:error` | Agent crashes, beam failures, LLM API errors |

### Contextual Logging

Add structured context to all logs from an agent:

```elixir
defmodule MyApp.Agents.MonitoredAgent do
  use Lux.Agent

  def handle_signal(signal, agent) do
    Logger.metadata(
      agent_id: agent.id,
      signal_id: signal.id,
      schema: signal.schema_id
    )

    Logger.info("Processing signal from #{signal.sender}")
    # ... process signal
  end
end
```

### Beam Execution Logging

Enable execution logs for detailed workflow tracing:

```elixir
defmodule MyApp.Beams.AuditedWorkflow do
  use Lux.Beam,
    name: "Audited Workflow",
    generate_execution_log: true

  sequence do
    step(:fetch, FetchLens, %{url: :url}, store_io: true)
    step(:process, TransformPrism, %{data: {:ref, "fetch"}}, store_io: true)
  end
end

# After execution:
{:ok, result, log} = AuditedWorkflow.run(input, return_log: true)

IO.inspect(log, label: "Execution Log")
# %{
#   beam_id: "beam_abc123",
#   status: :completed,
#   started_at: ~U[2025-01-15 12:00:00Z],
#   completed_at: ~U[2025-01-15 12:00:03Z],
#   steps: [
#     %{name: "fetch", duration_ms: 1200, status: :completed},
#     %{name: "process", duration_ms: 800, status: :completed}
#   ]
# }
```

## Telemetry Integration

### Built-in Telemetry Events

```elixir
# Agent lifecycle
[:lux, :agent, :lifecycle]  # measurements: %{duration: 450}
                             # metadata: %{agent_id: "...", event: :started}

# Beam step execution
[:lux, :beam, :step]        # measurements: %{duration: 1200}
                             # metadata: %{beam_id: "...", step: :fetch, status: :ok}

# Signal dispatch
[:lux, :signal, :dispatch]  # measurements: %{duration: 15}
                             # metadata: %{schema_id: "task_v1", from: "...", to: "..."}

# Lens HTTP request
[:lux, :lens, :request]     # measurements: %{duration: 350, status: 200}
                             # metadata: %{lens: "WeatherLens", url: "..."}

# LLM completion
[:lux, :llm, :completion]   # measurements: %{duration: 2200, tokens: 450}
                             # metadata: %{provider: :openai, model: "gpt-4o-mini"}
```

### Attaching Handlers

```elixir
# In your application startup (application.ex)
def start(_type, _args) do
  attach_telemetry_handlers()

  children = [...]
  Supervisor.start_link(children, strategy: :one_for_one)
end

defp attach_telemetry_handlers do
  # Performance monitoring
  :telemetry.attach_many(
    "lux-performance",
    [
      [:lux, :beam, :step],
      [:lux, :agent, :lifecycle],
      [:lux, :signal, :dispatch]
    ],
    &handle_performance_event/4,
    nil
  )

  # Cost tracking
  :telemetry.attach(
    "lux-cost-tracking",
    [:lux, :llm, :completion],
    &handle_llm_event/4,
    nil
  )

  # Error monitoring
  :telemetry.attach_many(
    "lux-errors",
    [
      [:lux, :beam, :step],
      [:lux, :lens, :request]
    ],
    &handle_error_event/4,
    nil
  )
end
```

### Prometheus Integration

```elixir
# mix.exs dependency
{:prom_ex, "~> 1.9"}

# Handler for Prometheus metrics
defmodule Lux.Metrics.PromExPlugin do
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      # Agent lifecycle counter
      Event.build(
        :lux_agent_lifecycle_total,
        [
          counter(
            event_name: [:lux, :agent, :lifecycle],
            measurement: :duration,
            tags: [:agent_id, :event],
            tag_values: &extract_agent_tags/1
          )
        ]
      ),

      # Beam step duration histogram
      Event.build(
        :lux_beam_step_duration,
        [
          distribution(
            event_name: [:lux, :beam, :step],
            measurement: :duration,
            unit: {:native, :millisecond},
            tags: [:beam_id, :step],
            tag_values: &extract_beam_tags/1,
            buckets: [10, 50, 100, 500, 1000, 5000, 30_000]
          )
        ]
      ),

      # LLM token usage counter
      Event.build(
        :lux_llm_tokens_total,
        [
          counter(
            event_name: [:lux, :llm, :completion],
            measurement: :tokens,
            tags: [:provider, :model],
            tag_values: &extract_llm_tags/1
          )
        ]
      )
    ]
  end

  defp extract_agent_tags(%{agent_id: id, event: event}), do: %{agent_id: id, event: event}
  defp extract_beam_tags(%{beam_id: bid, step: s}), do: %{beam_id: bid, step: s}
  defp extract_llm_tags(%{provider: p, model: m}), do: %{provider: p, model: m}
end
```

## Health Checks

### Agent Health Endpoint

```elixir
defmodule Lux.Monitoring.HealthController do
  use Phoenix.Controller

  def index(conn, _params) do
    checks = %{
      status: overall_status(),
      timestamp: DateTime.utc_now(),
      components: %{
        agent_hub: check_agent_hub(),
        llm_providers: check_llm_providers(),
        python_bridge: check_python_bridge(),
        memory: check_memory(),
        db: check_database()
      }
    }

    status_code = if checks.status == :healthy, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(checks)
  end

  defp check_agent_hub do
    case Lux.AgentHub.get_default() do
      nil -> %{status: :unhealthy, error: "AgentHub not running"}
      hub ->
        agents = Lux.AgentHub.list_agents(hub)
        online = Enum.count(agents, & &1.status != :offline)
        %{status: :healthy, total: length(agents), online: online}
    end
  end

  defp check_llm_providers do
    providers = [:openai, :anthropic]
    results = Enum.map(providers, fn provider ->
      case Lux.LLM.Monitor.ping(provider) do
        :ok -> {provider, :healthy}
        {:error, reason} -> {provider, %{status: :degraded, error: reason}}
      end
    end)
    %{status: if(Enum.all?(results, &match?({_, :healthy}, &1)), do: :healthy, else: :degraded),
      providers: Map.new(results)}
  end

  defp check_python_bridge do
    case Lux.Python.eval("True") do
      {:ok, true} -> %{status: :healthy}
      {:error, reason} -> %{status: :unhealthy, error: reason}
    end
  end

  defp check_memory do
    {:ok, mem} = Lux.Memory.initialize(backend: Lux.Memory.ETS)
    Lux.Memory.add(mem, "health_check", :system, %{check: true})
    {:ok, recent} = Lux.Memory.recent(mem, 1)
    if length(recent) == 1, do: %{status: :healthy}, else: %{status: :degraded}
  end

  defp overall_status do
    # Derive from component checks
    :healthy
  end
end
```

### Kubernetes Liveness and Readiness

```yaml
# livenessProbe — is the process alive?
livenessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 10

# readinessProbe — can the process accept traffic?
readinessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Alerting Rules

### Critical Alerts

| Alert | Condition | Threshold |
|-------|-----------|-----------|
| Agent Down | Agent status = `:offline` for > 30s | Immediate |
| Beam Failure Rate | Failure rate > 10% over 5 min | 5 min |
| LLM API Errors | 5xx errors > 5 in 1 min | 1 min |
| Python Bridge Dead | Python eval fails 3 consecutive times | Immediate |
| High Token Usage | Daily tokens > budget * 1.2 | Daily summary |

### Prometheus Alert Rules

```yaml
groups:
  - name: lux_alerts
    rules:
      - alert: AgentDown
        expr: lux_agent_lifecycle_total{event="stopped"} > 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Agent {{ $labels.agent_id }} is down"

      - alert: BeamFailureRate
        expr: |
          rate(lux_beam_step_duration_count{status="error"}[5m])
          / rate(lux_beam_step_duration_count[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Beam failure rate above 10%"

      - alert: LLMAPICostSpike
        expr: |
          rate(lux_llm_tokens_total[1h]) * 3600
          > 1000000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "LLM token usage spike detected"

      - alert: PythonBridgeUnhealthy
        expr: lux_python_errors_total > 3
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Python bridge has consecutive errors"
```

## Dashboard Recommendations

### Grafana Dashboard Panels

#### Agent Overview
```
Panel: Agent Status Distribution
Query: lux_agent_status{status=~"available|busy|offline"}
Type: Stat / Gauge

Panel: Signal Throughput
Query: rate(lux_signal_dispatch_duration_count[5m])
Type: Graph (line)

Panel: Active Beams
Query: lux_beam_step_duration_count
Type: Stat
```

#### LLM Cost Dashboard
```
Panel: Token Usage by Provider
Query: sum by (provider) (rate(lux_llm_tokens_total[1h]))
Type: Bar chart

Panel: Average Response Time
Query: histogram_quantile(0.95, rate(lux_llm_completion_duration_bucket[5m]))
Type: Graph (line)

Panel: Daily Cost Estimate
Query: sum(lux_llm_tokens_total) * $0.00015  # Adjust per model pricing
Type: Stat
```

#### Performance Dashboard
```
Panel: P95 Beam Step Duration
Query: histogram_quantile(0.95, rate(lux_beam_step_duration_bucket[5m]))
Type: Graph (line)

Panel: Lens Request Success Rate
Query: sum(rate(lux_lens_request_duration_count{status="success"}[5m]))
       / sum(rate(lux_lens_request_duration_count[5m])) * 100
Type: Stat (percentage)

Panel: Python Bridge Latency
Query: rate(lux_python_eval_duration_sum[5m]) / rate(lux_python_eval_duration_count[5m])
Type: Graph (line)
```

## Error Tracking and Debugging

### Agent Debug Mode

Enable per-agent debug logging:

```elixir
# Start agent with debug metadata
Logger.metadata(agent_id: agent.id, debug: true)

# In development, attach a tracer
:telemetry.attach("debug-tracer", [:lux, :agent, :lifecycle], fn
  _event, %{duration: d}, %{agent_id: id, event: e}, _ ->
    IO.puts("[#{id}] #{e} in #{div(d, 1000)}ms")
end, nil)
```

### Beam Execution Trace

```elixir
defmodule Lux.Debug.BeamTracer do
  def trace(beam_module, input) do
    IO.puts("=== Beam Execution Trace ===")
    IO.puts("Module: #{inspect(beam_module)}")

    {time, result} = :timer.tc(fn ->
      beam_module.run(input, return_log: true)
    end)

    case result do
      {:ok, result, log} ->
        IO.puts("Duration: #{div(time, 1000)}ms")
        IO.puts("Status: #{log.status}")
        IO.puts("Steps:")
        Enum.each(log.steps, fn step ->
          status_icon = if step.status == :completed, do: "✓", else: "✗"
          IO.puts("  #{status_icon} #{step.name}: #{step.duration_ms}ms")
          if step.error, do: IO.puts("    Error: #{inspect(step.error)}")
        end)
      {:error, reason} ->
        IO.puts("FAILED: #{inspect(reason)}")
    end
  end
end

# Usage
Lux.Debug.BeamTracer.trace(MyBeam, %{input: data})
```

### Signal Tracing

```elixir
# Trace all signal flow in development
:telemetry.attach("signal-tracer", [:lux, :signal, :dispatch], fn
  _event, _measurements, metadata, _ ->
    IO.puts("[SIGNAL] #{metadata.schema_id}: #{metadata.from} → #{metadata.to}")
end, nil)
```

## Log Aggregation Setup

### ELK Stack Integration

```elixir
# mix.exs
{:logger_file_backend, "~> 0.0.11"}

# config/prod.exs
config :logger,
  backends: [:console, {LoggerFileBackend, :json_log}]

config :logger, :json_log,
  path: "/var/log/lux/agent.json",
  level: :info,
  format: {Lux.Logging.JSONFormatter, :format},
  metadata: [:agent_id, :beam_id, :request_id, :company_id]
```

### Filebeat Configuration

```yaml
# /etc/filebeat/filebeat.yml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/lux/agent.json
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "lux-logs-%{+yyyy.MM.dd}"

setup.kibana:
  host: "kibana:5601"
```

## Monitoring Checklist

Before deploying to production, ensure:

- [ ] JSON structured logging enabled with agent/beam context in metadata
- [ ] Telemetry handlers attached for all relevant events
- [ ] Health check endpoint exposed (`/health`)
- [ ] Prometheus metrics exported for agent lifecycle, beam execution, and LLM usage
- [ ] Alert rules configured for agent down, beam failures, and cost spikes
- [ ] Grafana dashboard created with agent status, LLM costs, and performance panels
- [ ] Log aggregation pipeline configured (ELK, Loki, or cloud provider)
- [ ] Debug mode available for development troubleshooting
- [ ] P95 latency tracked for beam steps and LLM calls
- [ ] Daily token/cost tracking with budget alerts
- [ ] Python bridge health monitored via periodic health checks
