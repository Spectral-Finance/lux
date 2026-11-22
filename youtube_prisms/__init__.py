"""
Lux YouTube content-intelligence prisms (Spectral-Finance/lux issue #77).

This package is a dependency-free, deterministic Prism architecture for the
YouTube Data API v3, mirroring the lux monorepo's ``Lux.Prisms.*`` design:

    **Prisms are pure. All I/O lives in the client.**

Every prism subclasses :class:`~youtube_prisms.base.Prism`, declares a
``name`` / ``description`` / ``input_schema`` / ``output_schema`` (mirroring
``use Lux.Prism``) and implements ``handler(params) -> dict``. Calling a prism
validates the input against its schema and returns a
:class:`~youtube_prisms.base.PrismResult`. No prism opens a socket, reads the
clock, or mutates global state -- identical input always yields identical
output, so the whole decision surface is unit-testable offline.

The suite has two layers:

1. **Intelligence prisms** -- higher-level content-intelligence over already
   parsed resources (performance scoring, growth signals, engagement trends,
   SEO audits, revenue estimates, ...).
2. **Parsing-primitive prisms** -- one small prism per raw resource shape
   (``channels`` / ``videos`` / ``playlists`` / ``playlistItems`` / ``search``)
   that normalises the wire payload into a flat, typed ``dict`` the
   intelligence prisms consume.

Intelligence prisms
-------------------
Video:        :class:`VideoPerformancePrism`, :class:`VideoMetadataPrism`
Channel:      :class:`ChannelGrowthPrism`, :class:`ChannelBenchmarkPrism`
Discovery:    :class:`TrendingTopicsPrism`, :class:`ContentGapPrism`
Playlist:     :class:`PlaylistStatsPrism`, :class:`PlaylistOverviewPrism`
Engagement:   :class:`EngagementTrendPrism`, :class:`AudienceRetentionPrism`
Monetization: :class:`RevenueEstimatePrism`
SEO:          :class:`SeoAuditPrism`

Parsing-primitive prisms
------------------------
Channel:      :class:`ChannelStatsPrism`, :class:`ChannelResourcePrism`,
              :class:`SearchResultPrism`, :class:`ChannelListPrism`
Video:        :class:`VideoStatsPrism`, :class:`VideoResourcePrism`,
              :class:`VideoListPrism`
Playlist:     :class:`PlaylistResourcePrism`, :class:`PlaylistItemsPrism`,
              :class:`UploadsPrism`
Engagement:   :class:`EngagementPrism`, :class:`EngagementComparePrism`
Keywords:     :class:`KeywordPrism`, :class:`ChannelKeywordsPrism`

The :func:`build_registry` helper returns a :class:`PrismRegistry` pre-loaded
with all twenty-six prisms for name-based dispatch, mirroring how lux resolves
``Lux.Prisms.<Name>`` modules at runtime.

The ``youtube_client`` module (one level up) is the integration layer that
fetches raw resources from the YouTube Data API v3 and feeds the parsed
``dict`` into these prisms.
"""

from __future__ import annotations

from .base import (
    Prism,
    PrismError,
    PrismInput,
    PrismRegistry,
    PrismResult,
    build_registry,
)
from .channel import ChannelBenchmarkPrism, ChannelGrowthPrism
from .discovery import ContentGapPrism, TrendingTopicsPrism
from .engagement import AudienceRetentionPrism, EngagementTrendPrism
from .monetization import RevenueEstimatePrism
from .playlist import PlaylistOverviewPrism, PlaylistStatsPrism
from .primitives import (
    ChannelKeywordsPrism,
    ChannelListPrism,
    ChannelResourcePrism,
    ChannelStatsPrism,
    EngagementComparePrism,
    EngagementPrism,
    KeywordPrism,
    PlaylistItemsPrism,
    PlaylistResourcePrism,
    SearchResultPrism,
    UploadsPrism,
    VideoListPrism,
    VideoResourcePrism,
    VideoStatsPrism,
)
from .seo import SeoAuditPrism
from .video import VideoMetadataPrism, VideoPerformancePrism

__version__ = "1.1.0"

__all__ = [
    # core
    "Prism",
    "PrismError",
    "PrismInput",
    "PrismResult",
    "PrismRegistry",
    "build_registry",
    # intelligence prisms -- video
    "VideoPerformancePrism",
    "VideoMetadataPrism",
    # intelligence prisms -- channel
    "ChannelGrowthPrism",
    "ChannelBenchmarkPrism",
    # intelligence prisms -- discovery
    "TrendingTopicsPrism",
    "ContentGapPrism",
    # intelligence prisms -- playlist
    "PlaylistStatsPrism",
    "PlaylistOverviewPrism",
    # intelligence prisms -- engagement
    "EngagementTrendPrism",
    "AudienceRetentionPrism",
    # intelligence prisms -- monetization
    "RevenueEstimatePrism",
    # intelligence prisms -- seo
    "SeoAuditPrism",
    # parsing-primitive prisms -- channel
    "ChannelStatsPrism",
    "ChannelResourcePrism",
    "SearchResultPrism",
    "ChannelListPrism",
    # parsing-primitive prisms -- video
    "VideoStatsPrism",
    "VideoResourcePrism",
    "VideoListPrism",
    # parsing-primitive prisms -- playlist
    "PlaylistResourcePrism",
    "PlaylistItemsPrism",
    "UploadsPrism",
    # parsing-primitive prisms -- engagement
    "EngagementPrism",
    "EngagementComparePrism",
    # parsing-primitive prisms -- keywords
    "KeywordPrism",
    "ChannelKeywordsPrism",
    "__version__",
]