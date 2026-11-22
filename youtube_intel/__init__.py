"""
youtube_intel — YouTube Content Intelligence System for Spectral-Finance/lux.

Implements lux issue #69: "YouTube Content Intelligence System".

Public API
----------
    from youtube_intel import (
        # core
        YouTubeClient, RateLimiter, QuotaLimiter, EventEmitter,
        InMemoryPersistence, JsonFilePersistence,
        # analytics
        AnalyticsEngine, VideoMetrics,
        # models
        LinearRegression, LogisticRegression,
        PostingTimeOptimizer, PerformancePredictor,
        # optimizer
        TitleOptimizer, ThumbnailOptimizer, TagOptimizer,
        DescriptionGenerator, RecommendationEngine, TrendingTopicAnalyzer,
    )

The package is stdlib-only (urllib, math, statistics, json) so it drops into the
lux monorepo with zero third-party dependencies. See ``README.md`` for a mapping
of every component to the issue's acceptance criteria.
"""

from .core import (
    EventEmitter,
    ForbiddenError,
    InMemoryPersistence,
    JsonFilePersistence,
    NotFoundError,
    QuotaExceededError,
    QuotaLimiter,
    RateLimitedError,
    RateLimiter,
    ServerError,
    YouTubeAPIError,
    YouTubeClient,
)
from .analytics import AnalyticsEngine, VideoMetrics
from .models import (
    LinearRegression,
    LogisticRegression,
    PerformancePredictor,
    PostingTimeOptimizer,
)
from .optimizer import (
    DescriptionGenerator,
    RecommendationEngine,
    TagOptimizer,
    ThumbnailOptimizer,
    TitleOptimizer,
    TrendingTopicAnalyzer,
)

__version__ = "1.0.0"

__all__ = [
    # core
    "YouTubeAPIError",
    "NotFoundError",
    "ForbiddenError",
    "QuotaExceededError",
    "RateLimitedError",
    "ServerError",
    "YouTubeClient",
    "RateLimiter",
    "QuotaLimiter",
    "EventEmitter",
    "InMemoryPersistence",
    "JsonFilePersistence",
    # analytics
    "AnalyticsEngine",
    "VideoMetrics",
    # models
    "LinearRegression",
    "LogisticRegression",
    "PostingTimeOptimizer",
    "PerformancePredictor",
    # optimizer
    "TitleOptimizer",
    "ThumbnailOptimizer",
    "TagOptimizer",
    "DescriptionGenerator",
    "RecommendationEngine",
    "TrendingTopicAnalyzer",
    "__version__",
]