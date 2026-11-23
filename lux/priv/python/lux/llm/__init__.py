"""Unified LLM provider abstraction layer for Lux.

This package provides a universal interface for interacting with multiple LLM
providers (OpenAI, Anthropic, Ollama/local, ...) behind a single, consistent
API. It implements the acceptance criteria for issue #99:

* Universal provider interface  -> :class:`lux.llm.base.LLMProvider`
* Provider registry / management -> :class:`lux.llm.registry.ProviderRegistry`
* Automatic model selection      -> :class:`lux.llm.selection.ModelSelector`
* Intelligent fallback handling  -> :class:`lux.llm.fallback.FallbackChain`
* Cost tracking & optimization   -> :mod:`lux.llm.monitoring`
* Performance monitoring         -> :mod:`lux.llm.monitoring`
* Caching / optimization         -> :class:`lux.llm.cache.SimpleCache`

Quick start::

    from lux.llm import get_provider, Message

    provider = get_provider("openai")           # via registry + env config
    reply = provider.complete([Message.user("Hello!")])
    print(reply.text)

Streaming::

    for chunk in provider.stream([Message.user("Count to three")]):
        print(chunk.text, end="")

The HTTP layer uses only the Python standard library (``urllib``) so the module
has **zero third-party dependencies** and unit tests never touch the network.
"""

from lux.llm.base import (
    LLMProvider,
    ProviderError,
    RateLimitError,
    RetryableError,
    AuthError,
    CompletionResponse,
    StreamChunk,
    Usage,
)
from lux.llm.message import Message, Role, ToolCall
from lux.llm.providers import AnthropicProvider, OllamaProvider, OpenAIProvider
from lux.llm.registry import ProviderRegistry, get_provider, register_provider
from lux.llm.factory import create_provider
from lux.llm.fallback import FallbackChain
from lux.llm.selection import ModelSelector, ModelSpec
from lux.llm.monitoring import CostTracker, MetricsCollector
from lux.llm.cache import SimpleCache
from lux.llm.config import LLMConfig, load_config

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
    "ModelSpec",
    "CostTracker",
    "MetricsCollector",
    "SimpleCache",
    "LLMConfig",
    "load_config",
]

__version__ = "0.1.0"