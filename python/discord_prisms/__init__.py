"""
discord_prisms — Core Discord prisms for the Spectral-Finance/lux integration.

Implements lux issue #57: "Discord Core Prisms, Lenses and Beams".

Public API
----------
    from discord_prisms import (
        DiscordHTTP, RateLimiter, EventEmitter,
        MessageManagementPrism, ChannelManagementPrism,
        ModerationPrism, EventHandlingPrism,
    )

All prisms share a single rate-limited, retry-aware HTTP core and emit
structured events. See ``core.py`` and ``prisms.py`` for details.
"""

from .core import (
    DiscordAPIError,
    DiscordHTTP,
    EventEmitter,
    ForbiddenError,
    InMemoryPersistence,
    JsonFilePersistence,
    NotFoundError,
    Prism,
    RateLimitedError,
    RateLimiter,
    ServerError,
)
from .prisms import (
    ChannelManagementPrism,
    EventHandlingPrism,
    MessageManagementPrism,
    ModerationPrism,
)

__version__ = "1.0.0"

__all__ = [
    "DiscordAPIError",
    "DiscordHTTP",
    "EventEmitter",
    "ForbiddenError",
    "InMemoryPersistence",
    "JsonFilePersistence",
    "NotFoundError",
    "Prism",
    "RateLimitedError",
    "RateLimiter",
    "ServerError",
    "MessageManagementPrism",
    "ChannelManagementPrism",
    "ModerationPrism",
    "EventHandlingPrism",
    "__version__",
]