"""Provider registry and management system.

The registry maps a provider name (``"openai"``, ``"anthropic"``,
``"ollama"``) to a :class:`~lux.llm.base.LLMProvider` *factory* (a callable that
builds a configured provider instance). It supports lazy construction,
singleton caching, and registration of custom providers.
"""
from __future__ import annotations

from typing import Callable, Dict, List, Optional

from lux.llm.base import LLMProvider, ProviderError
from lux.llm.config import LLMConfig, load_config
from lux.llm.providers import AnthropicProvider, OllamaProvider, OpenAIProvider

ProviderFactory = Callable[..., LLMProvider]

# Built-in provider factories. Each accepts a config + overrides and returns a
# configured provider instance.
_BUILTIN: Dict[str, ProviderFactory] = {
    "openai": lambda cfg, **kw: OpenAIProvider(
        model=kw.get("model", "gpt-4o-mini"),
        api_key=kw.get("api_key", cfg.api_key("openai")),
        base_url=kw.get("base_url", cfg.base_url("openai")),
        **{k: v for k, v in kw.items() if k not in ("model", "api_key", "base_url")},
    ),
    "anthropic": lambda cfg, **kw: AnthropicProvider(
        model=kw.get("model", "claude-3-5-sonnet-latest"),
        api_key=kw.get("api_key", cfg.api_key("anthropic")),
        base_url=kw.get("base_url", cfg.base_url("anthropic")),
        **{k: v for k, v in kw.items() if k not in ("model", "api_key", "base_url")},
    ),
    "ollama": lambda cfg, **kw: OllamaProvider(
        model=kw.get("model", "llama3"),
        base_url=kw.get("base_url", cfg.base_url("ollama")),
        **{k: v for k, v in kw.items() if k not in ("model", "base_url")},
    ),
}


class ProviderRegistry:
    """Registry of provider factories with optional instance caching."""

    def __init__(self, config: Optional[LLMConfig] = None) -> None:
        self.config = config or load_config()
        self._factories: Dict[str, ProviderFactory] = dict(_BUILTIN)
        self._instances: Dict[str, LLMProvider] = {}

    def register(self, name: str, factory: ProviderFactory, *, override: bool = False) -> None:
        """Register a custom provider factory under ``name``."""
        if not override and name in self._factories:
            raise ProviderError(f"provider {name!r} already registered")
        self._factories[name] = factory
        self._instances.pop(name, None)

    def available(self) -> List[str]:
        """Return the names of all registered providers."""
        return sorted(self._factories)

    def is_available(self, name: str) -> bool:
        return name in self._factories

    def create(self, name: str, **overrides: object) -> LLMProvider:
        """Build (and cache) a provider instance by name."""
        if name not in self._factories:
            raise ProviderError(
                f"unknown provider {name!r}; available: {', '.join(self.available())}"
            )
        if not overrides and name in self._instances:
            return self._instances[name]
        provider = self._factories[name](self.config, **overrides)
        if not overrides:
            self._instances[name] = provider
        return provider

    def get(self, name: Optional[str] = None, **overrides: object) -> LLMProvider:
        """Alias for :meth:`create` defaulting to the configured provider."""
        return self.create(name or self.config.default_provider, **overrides)


# --------------------------------------------------------------------------- #
# Module-level default registry + convenience helpers
# --------------------------------------------------------------------------- #
_default_registry: Optional[ProviderRegistry] = None


def default_registry() -> ProviderRegistry:
    global _default_registry
    if _default_registry is None:
        _default_registry = ProviderRegistry()
    return _default_registry


def register_provider(name: str, factory: ProviderFactory, *, override: bool = False) -> None:
    """Register a custom provider on the default registry."""
    default_registry().register(name, factory, override=override)


def get_provider(name: Optional[str] = None, **overrides: object) -> LLMProvider:
    """Get a provider from the default registry (env-configured)."""
    return default_registry().get(name, **overrides)


def reset_default_registry() -> None:
    """Reset the module-level registry (primarily for tests)."""
    global _default_registry
    _default_registry = None