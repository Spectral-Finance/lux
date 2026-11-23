"""Unit tests for the unified LLM provider abstraction layer.

All HTTP is mocked via monkeypatching :func:`lux.llm.http_utils.http_post` and
:func:`lux.llm.http_utils.http_post_stream`, so no network access or API keys
are required.
"""
from __future__ import annotations

import pytest

from lux.llm import (
    AnthropicProvider,
    AuthError,
    FallbackChain,
    LLMConfig,
    Message,
    ModelSelector,
    ModelSpec,
    OllamaProvider,
    OpenAIProvider,
    ProviderError,
    ProviderRegistry,
    RateLimitError,
    Role,
    SimpleCache,
    Usage,
    create_provider,
)
from lux.llm import http_utils
from lux.llm.fallback import AllProvidersFailedError
from lux.llm.monitoring import CostTracker, MetricsCollector


# --------------------------------------------------------------------------- #
# Message / schema
# --------------------------------------------------------------------------- #
def test_message_constructors_and_roles():
    assert Message.system("s").role == Role.SYSTEM
    assert Message.user("u").role == Role.USER
    assert Message.assistant("a").role == Role.ASSISTANT
    assert Message.tool("t", name="fn").name == "fn"
    d = Message.user("hi").to_dict()
    assert d == {"role": "user", "content": "hi"}


def test_usage_total_and_from_dict():
    u = Usage.from_dict({"prompt_tokens": 3, "completion_tokens": 4})
    assert u.total_tokens == 7
    # Anthropic-style keys
    u2 = Usage.from_dict({"input_tokens": 5, "output_tokens": 6})
    assert u2.total_tokens == 11


# --------------------------------------------------------------------------- #
# OpenAI provider
# --------------------------------------------------------------------------- #
def _openai_response():
    return {
        "model": "gpt-4o-mini",
        "choices": [
            {
                "message": {"content": "Hello!", "role": "assistant"},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 10, "completion_tokens": 5},
    }


def test_openai_complete(monkeypatch):
    captured = {}

    def fake_post(url, body, headers=None, *, timeout=60.0, provider="base"):
        captured["url"] = url
        captured["body"] = body
        captured["headers"] = headers
        return _openai_response()

    monkeypatch.setattr(http_utils, "http_post", fake_post)
    provider = OpenAIProvider(model="gpt-4o-mini", api_key="sk-test")
    resp = provider.complete([Message.user("Hi")], temperature=0.2, max_tokens=50)

    assert resp.text == "Hello!"
    assert resp.provider == "openai"
    assert resp.usage.total_tokens == 15
    assert resp.finish_reason == "stop"
    assert captured["url"].endswith("/chat/completions")
    assert captured["headers"]["Authorization"] == "Bearer sk-test"
    assert captured["body"]["temperature"] == 0.2
    assert captured["body"]["max_tokens"] == 50
    assert captured["body"]["messages"] == [{"role": "user", "content": "Hi"}]


def test_openai_stream(monkeypatch):
    # http_post_stream yields bare JSON payload strings (data: prefix stripped).
    events = [
        '{"choices":[{"delta":{"content":"Hel"}}]}',
        '{"choices":[{"delta":{"content":"lo"}}]}',
        '{"choices":[{"delta":{},"finish_reason":"stop"}]}',
        "[DONE]",
    ]

    def fake_stream(url, body, headers=None, *, timeout=60.0, provider="base"):
        assert body["stream"] is True
        return iter(events)

    monkeypatch.setattr(http_utils, "http_post_stream", fake_stream)
    provider = OpenAIProvider(model="gpt-4o-mini", api_key="sk-test")
    chunks = list(provider.stream([Message.user("Hi")]))
    text = "".join(c.text for c in chunks)
    assert text == "Hello"
    assert chunks[-1].done is True


# --------------------------------------------------------------------------- #
# Anthropic provider
# --------------------------------------------------------------------------- #
def test_anthropic_complete(monkeypatch):
    captured = {}

    def fake_post(url, body, headers=None, *, timeout=60.0, provider="base"):
        captured["body"] = body
        captured["headers"] = headers
        return {
            "model": "claude-3-5-sonnet-latest",
            "content": [{"type": "text", "text": "Hi there"}],
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 8, "output_tokens": 3},
        }

    monkeypatch.setattr(http_utils, "http_post", fake_post)
    provider = AnthropicProvider(model="claude-3-5-sonnet-latest", api_key="ak-test")
    resp = provider.complete(
        [Message.system("be nice"), Message.user("Hi")], max_tokens=100
    )

    assert resp.text == "Hi there"
    assert resp.provider == "anthropic"
    assert resp.usage.total_tokens == 11
    # system message extracted separately
    assert captured["body"]["system"] == "be nice"
    assert captured["body"]["messages"] == [{"role": "user", "content": "Hi"}]
    assert captured["headers"]["x-api-key"] == "ak-test"
    assert captured["headers"]["anthropic-version"] == "2023-06-01"


def test_anthropic_stream(monkeypatch):
    events = [
        '{"type":"content_block_delta","delta":{"text":"A"}}',
        '{"type":"content_block_delta","delta":{"text":"B"}}',
        '{"type":"message_delta","delta":{"stop_reason":"end_turn"}}',
        '{"type":"message_stop"}',
    ]

    def fake_stream(url, body, headers=None, *, timeout=60.0, provider="base"):
        return iter(events)

    monkeypatch.setattr(http_utils, "http_post_stream", fake_stream)
    provider = AnthropicProvider(model="claude-3-5-sonnet-latest", api_key="ak")
    chunks = list(provider.stream([Message.user("Hi")]))
    assert "".join(c.text for c in chunks) == "AB"
    assert any(c.done for c in chunks)


# --------------------------------------------------------------------------- #
# Ollama provider
# --------------------------------------------------------------------------- #
def test_ollama_complete(monkeypatch):
    captured = {}

    def fake_post(url, body, headers=None, *, timeout=60.0, provider="base"):
        captured["url"] = url
        captured["body"] = body
        return {
            "model": "llama3",
            "message": {"role": "assistant", "content": "local reply"},
            "done": True,
            "prompt_eval_count": 12,
            "eval_count": 4,
        }

    monkeypatch.setattr(http_utils, "http_post", fake_post)
    provider = OllamaProvider(model="llama3")
    resp = provider.complete([Message.user("Hi")], temperature=0.1)

    assert resp.text == "local reply"
    assert resp.provider == "ollama"
    assert resp.usage.prompt_tokens == 12
    assert resp.usage.completion_tokens == 4
    assert captured["url"].endswith("/api/chat")
    assert captured["body"]["options"]["temperature"] == 0.1


def test_ollama_stream(monkeypatch):
    lines = [
        '{"message":{"content":"x"},"done":false}',
        '{"message":{"content":"y"},"done":false}',
        '{"message":{"content":""},"done":true,"prompt_eval_count":2,"eval_count":2}',
    ]

    def fake_stream(url, body, headers=None, *, timeout=60.0, provider="base"):
        return iter(lines)

    monkeypatch.setattr(http_utils, "http_post_stream", fake_stream)
    provider = OllamaProvider(model="llama3")
    chunks = list(provider.stream([Message.user("Hi")]))
    assert "".join(c.text for c in chunks) == "xy"
    assert chunks[-1].done is True
    assert chunks[-1].usage.total_tokens == 4


# --------------------------------------------------------------------------- #
# Retry behaviour
# --------------------------------------------------------------------------- #
def test_retry_then_success(monkeypatch):
    calls = {"n": 0}

    def flaky_post(url, body, headers=None, *, timeout=60.0, provider="base"):
        calls["n"] += 1
        if calls["n"] < 3:
            raise RateLimitError("slow down", provider="openai")
        return _openai_response()

    monkeypatch.setattr(http_utils, "http_post", flaky_post)
    monkeypatch.setattr("time.sleep", lambda *_: None)
    provider = OpenAIProvider(model="gpt-4o-mini", api_key="sk", max_retries=3)
    resp = provider.complete([Message.user("Hi")])
    assert resp.text == "Hello!"
    assert calls["n"] == 3


def test_auth_error_not_retried(monkeypatch):
    calls = {"n": 0}

    def auth_post(url, body, headers=None, *, timeout=60.0, provider="base"):
        calls["n"] += 1
        raise AuthError("bad key", status_code=401, provider="openai")

    monkeypatch.setattr(http_utils, "http_post", auth_post)
    provider = OpenAIProvider(model="gpt-4o-mini", api_key="bad", max_retries=3)
    with pytest.raises(AuthError):
        provider.complete([Message.user("Hi")])
    assert calls["n"] == 1


# --------------------------------------------------------------------------- #
# Registry / factory
# --------------------------------------------------------------------------- #
def test_registry_lists_and_creates():
    reg = ProviderRegistry(LLMConfig(api_keys={"openai": "sk", "anthropic": "ak"}))
    assert set(reg.available()) == {"openai", "anthropic", "ollama"}
    p = reg.create("openai")
    assert isinstance(p, OpenAIProvider)
    assert p.api_key == "sk"
    # cached instance
    assert reg.create("openai") is p


def test_registry_unknown_provider():
    reg = ProviderRegistry()
    with pytest.raises(ProviderError):
        reg.create("does-not-exist")


def test_registry_custom_provider():
    reg = ProviderRegistry()
    sentinel = OllamaProvider(model="custom")
    reg.register("my-local", lambda cfg, **kw: sentinel)
    assert reg.is_available("my-local")
    assert reg.create("my-local") is sentinel


def test_factory_create_provider():
    cfg = LLMConfig(api_keys={"anthropic": "ak"})
    p = create_provider("anthropic", config=cfg)
    assert isinstance(p, AnthropicProvider)
    assert p.api_key == "ak"


def test_config_from_env():
    cfg = LLMConfig(
        default_provider="openai",
        api_keys={"openai": "sk"},
        base_urls={"ollama": "http://host:1234"},
        fallback_providers=["anthropic", "ollama"],
    )
    assert cfg.api_key("openai") == "sk"
    assert cfg.base_url("ollama") == "http://host:1234"


def test_load_config_from_mapping():
    from lux.llm.config import load_config

    cfg = load_config(
        {
            "OPENAI_API_KEY": "sk-env",
            "ANTHROPIC_API_KEY": "ak-env",
            "OLLAMA_BASE_URL": "http://ollama:11434",
            "LUX_LLM_DEFAULT_PROVIDER": "anthropic",
            "LUX_LLM_FALLBACK_PROVIDERS": "openai, ollama",
        }
    )
    assert cfg.default_provider == "anthropic"
    assert cfg.api_key("openai") == "sk-env"
    assert cfg.base_url("ollama") == "http://ollama:11434"
    assert cfg.fallback_providers == ["openai", "ollama"]


# --------------------------------------------------------------------------- #
# Fallback chain
# --------------------------------------------------------------------------- #
class _FakeProvider:
    def __init__(self, name, *, fail=False, text="ok"):
        self.name = name
        self.fail = fail
        self.text = text
        self.model = "m"
        self.base_url = ""

    def complete(self, messages, **params):
        if self.fail:
            raise ProviderError(f"{self.name} down", provider=self.name)
        from lux.llm.base import CompletionResponse

        return CompletionResponse(text=self.text, model="m", provider=self.name)

    def stream(self, messages, **params):
        from lux.llm.base import StreamChunk

        if self.fail:
            raise ProviderError(f"{self.name} down", provider=self.name)
        yield StreamChunk(text=self.text, model="m", provider=self.name, done=True)


def test_fallback_chain_failover():
    primary = _FakeProvider("primary", fail=True)
    secondary = _FakeProvider("secondary", text="from-secondary")
    chain = FallbackChain([primary, secondary])
    resp = chain.complete([Message.user("Hi")])
    assert resp.provider == "secondary"
    assert resp.text == "from-secondary"


def test_fallback_chain_all_fail():
    chain = FallbackChain([_FakeProvider("a", fail=True), _FakeProvider("b", fail=True)])
    with pytest.raises(AllProvidersFailedError):
        chain.complete([Message.user("Hi")])


def test_fallback_chain_stream_failover():
    chain = FallbackChain(
        [_FakeProvider("a", fail=True), _FakeProvider("b", text="streamed")]
    )
    chunks = list(chain.stream([Message.user("Hi")]))
    assert "".join(c.text for c in chunks) == "streamed"


# --------------------------------------------------------------------------- #
# Model selection
# --------------------------------------------------------------------------- #
def test_model_selector_quality():
    sel = ModelSelector()
    spec = sel.select(optimize_for="quality")
    assert spec.quality_tier == 5


def test_model_selector_cost():
    sel = ModelSelector()
    spec = sel.select(provider="openai", optimize_for="cost")
    assert spec.name == "gpt-4o-mini"


def test_model_selector_constraints():
    sel = ModelSelector()
    spec = sel.select(need_tools=True, min_context=100000, optimize_for="cost")
    assert spec.context_window >= 100000
    assert spec.supports_tools


def test_model_selector_prefer():
    sel = ModelSelector()
    spec = sel.select(prefer="claude-3-5-sonnet-latest")
    assert spec.name == "claude-3-5-sonnet-latest"


def test_model_selector_no_match():
    sel = ModelSelector()
    with pytest.raises(ValueError):
        sel.select(provider="ollama", need_vision=True)


# --------------------------------------------------------------------------- #
# Monitoring / cost tracking
# --------------------------------------------------------------------------- #
def test_cost_tracker():
    from lux.llm.base import CompletionResponse

    tracker = CostTracker()
    resp = CompletionResponse(
        text="x",
        model="gpt-4o-mini",
        provider="openai",
        usage=Usage(prompt_tokens=1_000_000, completion_tokens=1_000_000),
    )
    tracker.record(resp)
    # gpt-4o-mini: 0.15 + 0.60 = 0.75
    assert abs(tracker.total_cost_usd - 0.75) < 1e-9
    summary = tracker.summary()
    assert summary["requests"] == 1
    assert summary["total_tokens"] == 2_000_000


def test_metrics_collector():
    mc = MetricsCollector()
    mc.record("openai", "gpt-4o-mini", 100.0, True)
    mc.record("openai", "gpt-4o-mini", 300.0, False)
    stats = mc.stats()
    assert stats["count"] == 2
    assert stats["mean_ms"] == 200.0
    assert stats["error_rate"] == 0.5


def test_metrics_timed_context():
    mc = MetricsCollector()
    with mc.timed("openai", "gpt-4o-mini"):
        pass
    assert mc.stats()["count"] == 1


# --------------------------------------------------------------------------- #
# Cache
# --------------------------------------------------------------------------- #
def test_cache_hit_miss():
    from lux.llm.base import CompletionResponse
    from lux.llm.cache import make_cache_key

    cache = SimpleCache(max_size=2)
    key = make_cache_key("openai", "gpt-4o-mini", [Message.user("Hi")])
    assert cache.get(key) is None
    resp = CompletionResponse(text="cached", model="gpt-4o-mini", provider="openai")
    cache.set(key, resp)
    assert cache.get(key) is resp
    stats = cache.stats()
    assert stats["hits"] == 1
    assert stats["misses"] == 1


def test_cache_eviction():
    from lux.llm.base import CompletionResponse

    cache = SimpleCache(max_size=2)
    for i in range(3):
        cache.set(f"k{i}", CompletionResponse(text=str(i), model="m", provider="p"))
    assert cache.get("k0") is None  # evicted (oldest)
    assert cache.get("k2") is not None