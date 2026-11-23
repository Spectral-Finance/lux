"""Environment-driven configuration for the LLM layer.

Configuration is read from environment variables with sensible defaults so the
layer works out-of-the-box in CI (no keys required for local providers) while
picking up real credentials in production.

Recognised variables
--------------------
``LUX_LLM_DEFAULT_PROVIDER``   provider name (default ``"openai"``)
``OPENAI_API_KEY``             OpenAI credential
``OPENAI_BASE_URL``            override OpenAI endpoint
``ANTHROPIC_API_KEY``          Anthropic credential
``ANTHROPIC_BASE_URL``         override Anthropic endpoint
``OLLAMA_BASE_URL``            Ollama endpoint (default ``http://localhost:11434``)
``LUX_LLM_FALLBACK_PROVIDERS`` comma-separated fallback chain
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    value = os.environ.get(name)
    if value is None:
        return default
    value = value.strip()
    return value or default


@dataclass
class LLMConfig:
    """Resolved configuration for the LLM layer."""

    default_provider: str = "openai"
    api_keys: Dict[str, str] = field(default_factory=dict)
    base_urls: Dict[str, str] = field(default_factory=dict)
    fallback_providers: List[str] = field(default_factory=list)

    def api_key(self, provider: str) -> Optional[str]:
        return self.api_keys.get(provider)

    def base_url(self, provider: str) -> Optional[str]:
        return self.base_urls.get(provider)


def load_config(environ: Optional[Dict[str, str]] = None) -> LLMConfig:
    """Build an :class:`LLMConfig` from ``environ`` (defaults to ``os.environ``)."""
    env = environ if environ is not None else dict(os.environ)

    def get(name: str, default: Optional[str] = None) -> Optional[str]:
        value = env.get(name)
        if value is None:
            return default
        value = value.strip()
        return value or default

    api_keys: Dict[str, str] = {}
    base_urls: Dict[str, str] = {}

    if get("OPENAI_API_KEY"):
        api_keys["openai"] = get("OPENAI_API_KEY", "")
    if get("ANTHROPIC_API_KEY"):
        api_keys["anthropic"] = get("ANTHROPIC_API_KEY", "")
    if get("OPENAI_BASE_URL"):
        base_urls["openai"] = get("OPENAI_BASE_URL", "")
    if get("ANTHROPIC_BASE_URL"):
        base_urls["anthropic"] = get("ANTHROPIC_BASE_URL", "")
    if get("OLLAMA_BASE_URL"):
        base_urls["ollama"] = get("OLLAMA_BASE_URL", "")

    fallback_raw = get("LUX_LLM_FALLBACK_PROVIDERS", "")
    fallback = [p.strip() for p in fallback_raw.split(",") if p.strip()] if fallback_raw else []

    return LLMConfig(
        default_provider=get("LUX_LLM_DEFAULT_PROVIDER", "openai") or "openai",
        api_keys=api_keys,
        base_urls=base_urls,
        fallback_providers=fallback,
    )