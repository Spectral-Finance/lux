# LLM Provider Abstraction Layer

A unified, provider-agnostic interface for interacting with multiple LLM
providers (OpenAI, Anthropic, Ollama/local) behind a single consistent API.
Implements the acceptance criteria for issue #99.

## Features

- **Universal provider interface** — `lux.llm.base.LLMProvider` ABC with
  `complete()` and `stream()`.
- **Concrete providers** — `OpenAIProvider`, `AnthropicProvider`,
  `OllamaProvider` (local / self-hosted).
- **Provider registry & management** — `ProviderRegistry` with lazy
  construction, instance caching, and custom provider registration.
- **Automatic model selection** — `ModelSelector` picks a model by
  quality / cost / latency and capability constraints.
- **Intelligent fallback handling** — `FallbackChain` fails over across
  providers on transient errors.
- **Cost tracking & optimization** — `CostTracker` estimates spend per
  provider/model.
- **Performance monitoring & analytics** — `MetricsCollector` records
  latency and error rates with p95 statistics.
- **Caching** — `SimpleCache`, a thread-safe bounded response cache.
- **Configuration via environment** — `LLMConfig` / `load_config()`.

The HTTP layer uses only the Python standard library (`urllib`), so the module
has **zero third-party dependencies** and unit tests never touch the network.

## Quick start

```python
from lux.llm import get_provider, Message

provider = get_provider("openai")            # via registry + env config
reply = provider.complete([Message.user("Hello!")])
print(reply.text)
```

### Streaming

```python
for chunk in provider.stream([Message.user("Count to three")]):
    print(chunk.text, end="")
```

### Fallback chain

```python
from lux.llm import FallbackChain, get_provider

chain = FallbackChain([
    get_provider("openai"),
    get_provider("anthropic"),
    get_provider("ollama"),
])
reply = chain.complete([Message.user("Hello!")])   # auto-failover
```

### Model selection

```python
from lux.llm import ModelSelector

selector = ModelSelector()
spec = selector.select(need_tools=True, optimize_for="cost")
print(spec.provider, spec.name)
```

### Cost tracking & metrics

```python
from lux.llm import CostTracker, MetricsCollector

tracker = CostTracker()
tracker.record(reply)
print(tracker.summary())          # {'requests': 1, 'total_cost_usd': ...}

metrics = MetricsCollector()
metrics.record_response(reply)
print(metrics.stats())            # {'count': 1, 'mean_ms': ..., 'p95_ms': ...}
```

## Configuration

Configuration is read from environment variables (see `lux.llm.config`):

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | OpenAI credential |
| `ANTHROPIC_API_KEY` | Anthropic credential |
| `OLLAMA_BASE_URL` | Ollama endpoint (default `http://localhost:11434`) |
| `LUX_LLM_DEFAULT_PROVIDER` | Default provider name |
| `LUX_LLM_FALLBACK_PROVIDERS` | Comma-separated fallback order |

## Testing

```bash
pytest -q
```

The suite mocks all HTTP (no live API keys required).