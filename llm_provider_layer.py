#!/usr/bin/env python3
"""Runnable entry point / demo CLI for the Lux LLM provider abstraction layer.

This is the top-level, user-facing front door for the ``lux.llm`` package that
implements issue #99. It is intentionally *executable* (not just a re-export
shim): you can drive the whole abstraction from the command line.

The real implementation lives in ``lux/priv/python/lux/llm``:

* ``base.py``       -- ``LLMProvider`` ABC + retry/backoff ``BaseProvider``
* ``providers.py``  -- ``OpenAIProvider`` / ``AnthropicProvider`` / ``OllamaProvider``
* ``registry.py``   -- ``ProviderRegistry`` (provider management)
* ``factory.py``    -- ``create_provider`` helper
* ``selection.py``  -- ``ModelSelector`` (automatic model selection)
* ``fallback.py``   -- ``FallbackChain`` (intelligent failover)
* ``monitoring.py`` -- ``CostTracker`` + ``MetricsCollector``
* ``cache.py``      -- ``SimpleCache`` (optimisation)
* ``config.py``     -- ``LLMConfig`` / ``load_config`` (env config)
* ``client.py``     -- ``LLMClient`` (orchestrates all of the above)

Usage
-----
    # Offline self-test: exercises every component with a fake provider,
    # no network and no API keys required. Always safe to run.
    python llm_provider_layer.py selftest

    # One-shot completion against a real provider (needs the matching env key,
    # e.g. OPENAI_API_KEY). Streams tokens to stdout.
    python llm_provider_layer.py complete "Hello, world!" --provider openai

    # List the registered providers and the default model catalogue.
    python llm_provider_layer.py providers
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import Iterator, List, Sequence

# Make ``lux`` importable when this file is executed directly from the repo root
# (i.e. without installing the package or setting PYTHONPATH).
_PKG_PARENT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "lux", "priv", "python"
)
if os.path.isdir(_PKG_PARENT) and _PKG_PARENT not in sys.path:
    sys.path.insert(0, _PKG_PARENT)

from lux.llm import (  # noqa: E402  (import after sys.path tweak)
    AnthropicProvider,
    AuthError,
    CompletionResponse,
    CostTracker,
    FallbackChain,
    LLMClient,
    LLMConfig,
    LLMProvider,
    Message,
    MetricsCollector,
    ModelSelector,
    OllamaProvider,
    OpenAIProvider,
    ProviderError,
    ProviderRegistry,
    RateLimitError,
    RetryableError,
    Role,
    SimpleCache,
    StreamChunk,
    ToolCall,
    Usage,
    create_provider,
    get_provider,
    load_config,
    register_provider,
)

__all__ = [
    "LLMProvider",
    "ProviderError",
    "RateLimitError",
    "RetryableError",
    "AuthError",
    "CompletionResponse",
    "StreamChunk",
    "Usage",
    "Message",
    "Role",
    "ToolCall",
    "OpenAIProvider",
    "AnthropicProvider",
    "OllamaProvider",
    "ProviderRegistry",
    "get_provider",
    "register_provider",
    "create_provider",
    "FallbackChain",
    "ModelSelector",
    "CostTracker",
    "MetricsCollector",
    "SimpleCache",
    "LLMConfig",
    "load_config",
    "LLMClient",
    "main",
]


# --------------------------------------------------------------------------- #
# Offline demo provider (used by ``selftest`` -- no network, no keys)
# --------------------------------------------------------------------------- #
class _EchoProvider(LLMProvider):
    """A deterministic offline provider used to exercise the layer in CI."""

    name = "echo"

    def __init__(self, **kw: object) -> None:
        super().__init__(model="echo-1", **kw)  # type: ignore[arg-type]

    def complete(
        self,
        messages: Sequence[Message],
        *,
        model: "str | None" = None,
        temperature: "float | None" = None,
        max_tokens: "int | None" = None,
        **params: object,
    ) -> CompletionResponse:
        last = messages[-1].content if messages else ""
        return CompletionResponse(
            text=f"echo: {last}",
            model=self.model,
            provider=self.name,
            usage=Usage(prompt_tokens=len(last.split()), completion_tokens=2),
            finish_reason="stop",
        )

    def stream(
        self,
        messages: Sequence[Message],
        *,
        model: "str | None" = None,
        temperature: "float | None" = None,
        max_tokens: "int | None" = None,
        **params: object,
    ) -> Iterator[StreamChunk]:
        last = messages[-1].content if messages else ""
        for word in f"echo: {last}".split():
            yield StreamChunk(text=word + " ", model=self.model, provider=self.name)
        yield StreamChunk(text="", model=self.model, provider=self.name, finish_reason="stop", done=True)


# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #
def cmd_selftest(_args: argparse.Namespace) -> int:
    """Exercise every component offline and print a summary. Returns exit code."""
    checks: List["tuple[str, bool]"] = []

    # 1) Registry + custom provider registration.
    registry = ProviderRegistry(LLMConfig())
    registry.register("echo", lambda cfg, **kw: _EchoProvider(), override=True)
    provider = registry.create("echo")
    checks.append(("registry creates echo provider", provider.name == "echo"))

    # 2) Non-streaming completion through the high-level client (with cache).
    client = LLMClient(registry=registry, cache=SimpleCache(max_size=16))
    r1 = client.complete([Message.user("hello world")], provider="echo")
    r2 = client.complete([Message.user("hello world")], provider="echo")  # cache hit
    checks.append(("client.complete returns echo text", r1.text == "echo: hello world"))
    checks.append(("client cache serves repeat call", r1 is r2))

    # 3) Streaming.
    chunks = list(client.stream([Message.user("stream me")], provider="echo"))
    streamed = "".join(c.text for c in chunks).strip()
    checks.append(("client.stream yields text", streamed == "echo: stream me"))
    checks.append(("client.stream marks done", chunks[-1].done is True))

    # 4) Fallback chain: a failing primary fails over to the echo provider.
    class _Boom(LLMProvider):
        name = "boom"

        def complete(self, messages, **kw):  # type: ignore[override]
            raise RateLimitError("primary down", provider="boom")

        def stream(self, messages, **kw):  # type: ignore[override]
            raise RateLimitError("primary down", provider="boom")

    chain = FallbackChain([_Boom(), _EchoProvider()])
    fb = chain.complete([Message.user("failover")])
    checks.append(("fallback chain fails over", fb.provider == "echo"))

    # 5) Model selection.
    spec = ModelSelector().select(provider="openai", optimize_for="cost")
    checks.append(("model selection picks cheapest openai", spec.name == "gpt-4o-mini"))

    # 6) Cost tracking + metrics were populated by the client calls above.
    summary = client.summary()
    checks.append(("cost tracker recorded usage", summary["cost"]["requests"] >= 1))
    checks.append(("metrics recorded latency", summary["metrics"]["count"] >= 1))

    # Report ---------------------------------------------------------------
    print("LLM provider abstraction layer -- offline self-test")
    print("=" * 52)
    ok = True
    for label, passed in checks:
        status = "PASS" if passed else "FAIL"
        ok = ok and passed
        print(f"  [{status}] {label}")
    print("-" * 52)
    print(f"providers available : {', '.join(registry.available())}")
    print(f"selected model      : {spec.provider}/{spec.name}")
    print(f"cost summary        : {summary['cost']}")
    print("=" * 52)
    print("RESULT:", "ALL CHECKS PASSED" if ok else "FAILURES DETECTED")
    return 0 if ok else 1


def cmd_providers(_args: argparse.Namespace) -> int:
    """List registered providers and the default model catalogue."""
    registry = ProviderRegistry(load_config())
    print("Registered providers:")
    for name in registry.available():
        print(f"  - {name}")
    print("\nDefault model catalogue:")
    for spec in ModelSelector().catalogue:
        caps = []
        if spec.supports_tools:
            caps.append("tools")
        if spec.supports_vision:
            caps.append("vision")
        cap_str = (" (" + ", ".join(caps) + ")") if caps else ""
        print(
            f"  - {spec.provider}/{spec.name}{cap_str} "
            f"[quality={spec.quality_tier} cost={spec.cost_tier} latency={spec.latency_tier}]"
        )
    return 0


def cmd_complete(args: argparse.Namespace) -> int:
    """One-shot completion against a real provider (streams to stdout)."""
    provider = get_provider(args.provider)
    messages = [Message.user(args.prompt)]
    print(f"[{provider.name}/{args.model or provider.model}] ", end="", flush=True)
    try:
        for chunk in provider.stream(messages, model=args.model):
            if chunk.text:
                print(chunk.text, end="", flush=True)
        print()
    except AuthError as exc:
        print(f"\nerror: authentication failed for {args.provider!r}: {exc}", file=sys.stderr)
        print(f"hint: set the {args.provider.upper()}_API_KEY environment variable", file=sys.stderr)
        return 2
    except ProviderError as exc:
        print(f"\nerror: {exc}", file=sys.stderr)
        return 1
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="llm_provider_layer",
        description="Lux LLM provider abstraction layer (issue #99).",
    )
    sub = parser.add_subparsers(dest="command")

    p_self = sub.add_parser("selftest", help="run the offline self-test (no network/keys)")
    p_self.set_defaults(func=cmd_selftest)

    p_prov = sub.add_parser("providers", help="list providers and the model catalogue")
    p_prov.set_defaults(func=cmd_providers)

    p_comp = sub.add_parser("complete", help="one-shot completion (streams tokens)")
    p_comp.add_argument("prompt", help="the user prompt")
    p_comp.add_argument("--provider", default=None, help="provider name (default: env config)")
    p_comp.add_argument("--model", default=None, help="model name override")
    p_comp.set_defaults(func=cmd_complete)

    return parser


def main(argv: "Sequence[str] | None" = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return 0
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())