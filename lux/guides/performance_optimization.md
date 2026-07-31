# Performance Optimization Guide

This guide covers strategies for optimizing the performance of Lux-based agent systems, from development through production.

## Profiling and Benchmarking

### Beam Execution Profiling

Use Beam execution logs to identify bottlenecks:

```elixir
# Enable execution logging for profiling
defmodule MyProfiledBeam do
  use Lux.Beam,
    name: "Profiled Workflow",
    generate_execution_log: true

  sequence do
    step(:slow_step, ExpensivePrism, %{data: :input})
    step(:fast_step, QuickPrism, %{data: {:ref, "slow_step"}})
  end
end

# After execution, analyze the log
{:ok, result, log} = MyProfiledBeam.run(input, return_log: true)

Enum.each(log.steps, fn step ->
  duration = DateTime.diff(step.completed_at, step.started_at, :millisecond)
  IO.puts("#{step.name}: #{duration}ms")
end)
```

### Agent Telemetry

Track agent performance metrics:

```elixir
:telemetry.attach_many("agent-perf", [
  [:lux, :agent, :signal, :process],
  [:lux, :agent, :llm, :call],
  [:lux, :agent, :memory, :access]
], fn event, measurements, metadata, _ ->
  case event do
    [:lux, :agent, :signal, :process] ->
      if measurements.duration > 5000 do
        Logger.warning("Slow signal processing: #{measurements.duration}ms for #{metadata.signal_id}")
      end
    _ -> :ok
  end
end, nil)
```

## LLM Optimization

### Response Caching

Cache identical LLM requests to reduce costs and latency:

```elixir
defmodule Lux.LLM.Cache do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def fetch_or_complete(prompt_hash, completion_fn) do
    case GenServer.call(__MODULE__, {:get, prompt_hash}) do
      {:hit, response} ->
        {:ok, response, %{cached: true}}

      :miss ->
        {:ok, response} = completion_fn.()
        GenServer.cast(__MODULE__, {:put, prompt_hash, response})
        {:ok, response, %{cached: false}}
    end
  end

  # GenServer callbacks
  def handle_call({:get, key}, _from, state) do
    case Map.get(state, key) do
      nil -> {:reply, :miss, state}
      value -> {:reply, {:hit, value}, state}
    end
  end

  def handle_cast({:put, key, value}, state) do
    # LRU-like eviction: keep last 1000 entries
    state = state |> Map.put(key, value)
    state = if map_size(state) > 1000, do: state |> Map.drop(List.first(Map.keys(state))), else: state
    {:noreply, state}
  end
end
```

### Model Selection Strategy

Use cheaper models for simple tasks:

```elixir
def select_model(task_complexity) do
  case task_complexity do
    :simple -> System.get_env("LUX_LLM_CHEAPEST", "gpt-4o-mini")
    :moderate -> System.get_env("LUX_LLM_DEFAULT", "gpt-4o-mini")
    :complex -> System.get_env("LUX_LLM_SMARTEST", "gpt-4o")
  end
end
```

### Token Budget Management

Set appropriate token limits per task:

| Task Type | Max Tokens | Model |
|-----------|-----------|-------|
| Classification | 50 | gpt-4o-mini |
| Summarization | 500 | gpt-4o-mini |
| Code Generation | 2000 | gpt-4o |
| Complex Reasoning | 4000 | gpt-4o |

## Concurrency and Parallelism

### Parallel Beam Steps

Identify independent steps and run them in parallel:

```elixir
# BEFORE (sequential):
sequence do
  step(:weather, WeatherLens, %{city: :city})
  step(:news, NewsLens, %{topic: :topic})
  step(:stocks, StockLens, %{symbol: :symbol})
end
# Duration: sum of all three (~3s)

# AFTER (parallel):
parallel do
  step(:weather, WeatherLens, %{city: :city})
  step(:news, NewsLens, %{topic: :topic})
  step(:stocks, StockLens, %{symbol: :symbol})
end
# Duration: max of longest (~1s)
```

### Agent Pool Sizing

Configure the number of concurrent agents based on workload:

```elixir
# Heuristic: 2 * CPU cores for I/O-bound agents
#            1 * CPU cores for CPU-bound agents

agent_count = System.schedulers_online() * 2
```

### Python Worker Tuning

For Python-heavy workflows:

```elixir
# In config/runtime.exs
python_worker_count = System.schedulers_online() * 2

config :venomous, :snake_manager, %{
  perpetual_workers: python_worker_count,
  snake_ttl_minutes: 15,
  cleaner_interval: 30_000
}
```

## Memory Management

### Agent State Pruning

Regularly prune agent memory to prevent unbounded growth:

```elixir
defmodule MyAgent do
  use Lux.Agent

  def prune_memory(state, opts \\ []) do
    max_entries = Keyword.get(opts, :max_entries, 1000)
    max_age_hours = Keyword.get(opts, :max_age_hours, 24)

    pruned_memory =
      state.memory
      |> Enum.reject(fn {_key, entry} ->
        age_hours = DateTime.diff(DateTime.utc_now(), entry.timestamp, :hour)
        age_hours > max_age_hours
      end)
      |> Enum.take(max_entries)
      |> Map.new()

    {:ok, %{state | memory: pruned_memory}}
  end
end
```

### Large Payload Handling

For large signal payloads, use references instead of embedding:

```elixir
# Instead of embedding large data in signals
signal = %Lux.Signal{
  content: %{data: huge_dataset}  # BAD: copies data
}

# Use references to shared storage
artifacts = Lux.Company.ExecutionEngine.ArtifactStore.store(huge_dataset)
signal = %Lux.Signal{
  content: %{data_ref: artifacts.id}  # GOOD: reference only
}
```

## Database and Storage Optimization

### Connection Pooling

Configure appropriate database connection pools:

```elixir
config :my_app, MyApp.Repo,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10")),
  queue_target: 500,
  queue_interval: 1000
```

### Batch Operations

Batch database writes instead of individual inserts:

```elixir
# BAD: N individual inserts
Enum.each(items, &Repo.insert!/1)

# GOOD: Single batch insert
Repo.insert_all("table_name", items)
```

## Caching Strategies

### Multi-Level Caching

```elixir
defmodule Lux.Cache.MultiLevel do
  def get(key) do
    case ets_lookup(key) do    # Level 1: In-memory ETS
      {:hit, value} -> {:ok, value, :l1_hit}
      :miss ->
        case redis_get(key) do  # Level 2: Redis
          {:ok, value} ->
            ets_insert(key, value)
            {:ok, value, :l2_hit}
          :miss ->
            :miss
        end
    end
  end
end
```

## Checklist

Before deploying to production, verify:

- [ ] Beam execution logs identify step-level bottlenecks
- [ ] Independent steps use `parallel` blocks
- [ ] LLM caching enabled for repeated queries
- [ ] Cheapest appropriate model selected per task
- [ ] Agent pool sized to available CPU cores
- [ ] Agent memory pruning configured
- [ ] Large payloads use artifact references
- [ ] Database connection pool tuned
- [ ] Python worker count matches expected concurrency
- [ ] Telemetry hooks attached for continuous monitoring
