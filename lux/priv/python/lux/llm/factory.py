"""Factory helpers for constructing providers from config or explicit kwargs."""
from __future__ import annotations

from typing import Optional

from lux.llm.base import LLMProvider
from lux.llm.config import LLMConfig, load_config
from lux.llm.registry import ProviderRegistry


def create_provider(
    name: Optional[str] = None,
    *,
    config: Optional[LLMConfig] = None,
    registry: Optional[ProviderRegistry] = None,
    **overrides: object,
) -> LLMProvider:
    """Create a provider instance.

    Parameters
    ----------
    name:
        Provider name (``"openai"``, ``"anthropic"``, ``"ollama"``). When
        ``None`` the configured default provider is used.
    config:
        Optional explicit :class:`~lux.llm.config.LLMConfig`.
    registry:
        Optional registry to source the provider from.
    **overrides:
        Forwarded to the provider constructor (e.g. ``model``, ``api_key``).
    """
    reg = registry or (ProviderRegistry(config) if config else None)
    if reg is not None:
        return reg.get(name, **overrides)
    from lux.llm.registry import get_provider

    return get_provider(name, **overrides)