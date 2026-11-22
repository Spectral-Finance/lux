"""
youtube_community_prisms — YouTube Community Management & Engagement prisms.

Implements lux issue #70: "YouTube Community Management and Engagement".

Public API
----------
    from youtube_community_prisms import (
        YouTubeHTTP, RateLimiter, EventEmitter,
        CommunityPostPrism, CommentModerationPrism, LiveChatPrism,
        MemberManagementPrism, AnalyticsPrism,
        analyze_sentiment, detect_spam, generate_response,
    )

All prisms share a single rate-limited, retry-aware HTTP core and emit
structured events. The package is stdlib-only and drops into the lux monorepo
(``lux/priv/python/lux/``) without adding transitive dependencies.
"""

from .analysis import (
    analyze_sentiment,
    detect_spam,
    generate_response,
    score_to_label,
)
from .core import (
    AuthenticationError,
    EventEmitter,
    ForbiddenError,
    InMemoryPersistence,
    JsonFilePersistence,
    NotFoundError,
    Prism,
    RateLimitedError,
    RateLimiter,
    ServerError,
    ValidationError,
    YouTubeAPIError,
    YouTubeHTTP,
)
from .prisms import (
    AnalyticsPrism,
    CommentModerationPrism,
    CommunityPostPrism,
    LiveChatPrism,
    MemberManagementPrism,
)

__version__ = "1.0.0"

__all__ = [
    # errors
    "YouTubeAPIError",
    "ValidationError",
    "AuthenticationError",
    "NotFoundError",
    "ForbiddenError",
    "RateLimitedError",
    "ServerError",
    # infrastructure
    "RateLimiter",
    "EventEmitter",
    "Prism",
    "YouTubeHTTP",
    "InMemoryPersistence",
    "JsonFilePersistence",
    # prisms
    "CommunityPostPrism",
    "CommentModerationPrism",
    "LiveChatPrism",
    "MemberManagementPrism",
    "AnalyticsPrism",
    # analysis
    "analyze_sentiment",
    "detect_spam",
    "generate_response",
    "score_to_label",
    "__version__",
]