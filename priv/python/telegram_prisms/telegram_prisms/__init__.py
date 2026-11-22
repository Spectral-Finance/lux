"""
telegram_prisms — Core Telegram prisms for the Spectral-Finance/lux integration.

Implements lux issue #62: "Telegram Core API Integration".

Public API
----------
    from telegram_prisms import (
        TelegramHTTP, TokenManager, RateLimiter, EventEmitter,
        BotPrism, MessagePrism, MediaPrism,
        KeyboardPrism, WebhookPrism, UpdatePrism,
    )

All prisms share a single rate-limited, retry-aware HTTP core and emit
structured events. See ``core.py`` and ``prisms.py`` for details.
"""

from .core import (
    ForbiddenError,
    InMemoryPersistence,
    JsonFilePersistence,
    NotFoundError,
    Prism,
    RateLimitedError,
    RateLimiter,
    ServerError,
    TelegramAPIError,
    TelegramHTTP,
    TokenManager,
    EventEmitter,
)
from .prisms import (
    BotPrism,
    KeyboardPrism,
    MediaPrism,
    MessagePrism,
    UpdatePrism,
    WebhookPrism,
)

__version__ = "1.0.0"

__all__ = [
    "TelegramAPIError",
    "NotFoundError",
    "ForbiddenError",
    "RateLimitedError",
    "ServerError",
    "TokenManager",
    "TelegramHTTP",
    "RateLimiter",
    "EventEmitter",
    "Prism",
    "InMemoryPersistence",
    "JsonFilePersistence",
    "BotPrism",
    "MessagePrism",
    "MediaPrism",
    "KeyboardPrism",
    "WebhookPrism",
    "UpdatePrism",
    "__version__",
]