# LLM Provider Abstraction Layer

Lux can talk to several LLM providers (Anthropic, OpenAI, Together AI, Mira, ...).
The provider layer gives every provider a uniform interface plus the machinery
to pick the right one per call, fall back when one fails, and keep an eye on
cost and latency.

```
                 ┌──────────────────────────────────────────────┐
                 │                Lux.LLM.Router                │
                 │  budget check → selection → retry → fallback │
                 └──────┬───────────────┬──────────────┬───────┘
                        │               │              │
              Lux.LLM.Selector   Lux.LLM.CircuitBreaker   Lux.LLM.Stats
                        │               │              │
              Lux.LLM.Registry   Lux.LLM.Cost      :telemetry events
                        │
              Lux.LLM.Provider (behaviour — implemented by every provider)
```

## Modules

| Module | Responsibility |
|---|---|
| `Lux.LLM.Provider` | The behaviour every provider implements (`meta/0` + the existing `call/3`), plus `model_meta/2` helpers. |
| `Lux.LLM.Registry` | Runtime registry of providers (GenServer + ETS). Register/unregister, health status, per-provider config. |
| `Lux.LLM.Selector` | Ranks the registered providers for each call: hard filters (context, tools, allow-list) then a weighted score (cost, capability, context, speed, weight). |
| `Lux.LLM.Router` | The orchestration entry point: budget check, selection, retries with backoff, fallback to the next provider, usage recording. |
| `Lux.LLM.Gateway` | Config-driven façade over the router: default requirements and provider registration from `config :lux, Lux.LLM.Gateway`. |
| `Lux.LLM.CircuitBreaker` | Per-provider breaker: `failure_threshold` consecutive failures open the circuit for `cooldown_ms`; one probe request closes it again. |
| `Lux.LLM.Cost` | Prices every routed call from the provider metadata, accumulates spend per provider/model and enforces a global budget. |
| `Lux.LLM.Stats` | Emits `[:lux, :llm, :call, :stop|:exception]` telemetry and aggregates latency percentiles, error rates and call counts. |

All state lives in ETS so the router hot path never blocks; the GenServers
only own registration and state transitions.

## Quick start

The layer starts automatically with the Lux application (it is part of the
supervision tree in `dev`/`prod`). Register the providers you want to use:

```elixir
# lib/my_app/application.ex
Lux.LLM.Registry.register(Lux.LLM.Anthropic)
Lux.LLM.Registry.register(Lux.LLM.OpenAI, model: "gpt-4o-mini", weight: 0.5)
Lux.LLM.Registry.register(Lux.LLM.TogetherAI)
Lux.LLM.Registry.register(Lux.LLM.Mira, weight: 2.0)  # free tier, preferred
```

or configure everything in one place and let the gateway do it at boot:

```elixir
# config/runtime.exs
config :lux, Lux.LLM.Gateway,
  default_requirements: %{quality: :balanced, prompt_tokens: 1_000},
  register: [
    {Lux.LLM.Anthropic, %{model: "claude-3-haiku-20240307"}},
    {Lux.LLM.Mira, %{weight: 2.0}}
  ]
```

Then route every call through the router:

```elixir
{:ok, response} = Lux.LLM.Router.call("Summarise this transaction", [],
  requirements: [quality: :cheap]
)
```

Direct provider calls keep working exactly as before:

```elixir
Lux.LLM.call("Hello", [], module: Lux.LLM.Anthropic)   # unchanged
Lux.LLM.Anthropic.call("Hello", [], %{})               # unchanged
```

## Automatic model selection

`Lux.LLM.Selector.rank/2` scores every *usable* provider for the requirements
of the current call and returns them best-first. Requirements (all optional):

| Key | Effect |
|---|---|
| `:prompt_tokens` | providers whose models have a smaller context window are filtered out |
| `:tools` | non-empty list ⇒ only models with the `:tools` capability |
| `:max_cost_usd` | models priced above the ceiling are filtered out |
| `:max_latency_ms` | soft preference for faster providers |
| `:quality` | `:cheap` (cost-first), `:balanced` (default), `:best` (capability-first) |
| `:providers` | explicit allow-list of provider modules |

```elixir
entries = Lux.LLM.Registry.available()

Lux.LLM.Selector.select(entries, prompt_tokens: 120_000, tools: [MyPrism], quality: :best)
#=> %{module: Lux.LLM.Anthropic, config: %{model: "claude-3-opus-20240229"}, ...}
```

The selected model is injected into the entry's config, so the router calls
the provider with exactly the model the selector picked.

## Fallback, retries and circuit breaking

`Lux.LLM.Router.call/3` tries the ranked providers in order:

1. providers whose circuit breaker is open are skipped;
2. transient errors (`:timeout`, `:econnrefused`, HTTP 429/500/502/503/504)
   are retried up to `:max_attempts` (default 2) with linear backoff
   (`:backoff_ms`, default 250);
3. a provider that keeps failing records a breaker failure — after
   `failure_threshold` consecutive failures the breaker opens for
   `cooldown_ms`, after which a single probe request decides whether it
   closes again;
4. the first success wins; if every provider fails the last error is returned.

```elixir
config :lux, Lux.LLM.CircuitBreaker,
  failure_threshold: 3,
  cooldown_ms: 60_000
```

## Cost tracking and budgets

Every routed call is priced from the provider metadata and accumulated per
provider/model:

```elixir
Lux.LLM.Cost.record(:anthropic, "claude-3-haiku-20240307", 1200, 350)
Lux.LLM.Cost.report()
#=> %{total_usd: 0.0011, by_provider: %{anthropic: 0.0011}, calls: 1}
```

Set a global budget and the router refuses new calls once it is exhausted
(`force: true` overrides, e.g. for critical paths):

```elixir
config :lux, Lux.LLM.Cost, budget_usd: 25.0

Lux.LLM.Router.call("critical summary", [], force: true)
```

A per-call ceiling is also available:

```elixir
Lux.LLM.Router.call("hello", [], budget_usd: 0.05)
```

## Monitoring

`Lux.LLM.Stats.measure/3` wraps every attempt. Attach any telemetry backend:

```elixir
:telemetry.attach_many(
  "my-llm-metrics",
  [[:lux, :llm, :call, :stop], [:lux, :llm, :call, :exception]],
  fn _event, measurements, metadata, _config ->
    # measurements: %{duration: ms}
    # metadata: %{provider: atom, model: String.t, status: :ok | :error, cost_usd: float}
    :telemetry_metrics...
  end,
  nil
)
```

Without a backend you still get aggregated snapshots:

```elixir
Lux.LLM.Stats.snapshot()
#=> %{
#     calls: 42,
#     errors: 2,
#     latency_ms: %{p50: 820, p95: 2400, max: 3100},
#     providers: %{anthropic: %{calls: 40, errors: 2, models: #MapSet<[]>}}
#   }
```

## Adding a provider

Implement `Lux.LLM` (the existing contract) and `Lux.LLM.Provider`:

```elixir
defmodule MyApp.LLM.MyProvider do
  @behaviour Lux.LLM
  @behaviour Lux.LLM.Provider

  @impl Lux.LLM.Provider
  def meta do
    %{
      name: :my_provider,
      supports_tools: true,
      models: [
        %{id: "my-model", input_cost_per_mtok: 1.0, output_cost_per_mtok: 2.0,
          max_context: 128_000, capabilities: [:tools, :json_mode]}
      ]
    }
  end

  @impl Lux.LLM
  def call(prompt, tools, options) do
    # ... talk to the API ...
    {:ok, %Lux.LLM.Response{content: "…"}}
  end
end

Lux.LLM.Registry.register(MyApp.LLM.MyProvider)
```

That is all: the provider is now selectable, monitored, cost-tracked and
protected by the circuit breaker.

## Tests

```console
mix test.unit          # runs the provider-layer unit tests (test/unit/lux/llm/)
```
