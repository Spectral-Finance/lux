"""
Lux YouTube content-intelligence prisms (Spectral-Finance/lux issue #75).

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

Concrete prisms
---------------
Video:        :class:`VideoPerformancePrism`, :class:`VideoMetadataPrism`
Channel:      :class:`ChannelGrowthPrism`, :class:`ChannelBenchmarkPrism`
Discovery:    :class:`TrendingTopicsPrism`, :class:`ContentGapPrism`
Monetization: :class:`RevenueEstimatePrism`
SEO:          :class:`SeoAuditPrism`

The :func:`build_registry` helper returns a :class:`PrismRegistry` pre-loaded
with all eight prisms for name-based dispatch, mirroring how lux resolves
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
from .monetization import RevenueEstimatePrism
from .seo import SeoAuditPrism
from .video import VideoMetadataPrism, VideoPerformancePrism

__version__ = "1.0.0"

__all__ = [
    # core
    "Prism",
    "PrismError",
    "PrismInput",
    "PrismResult",
    "PrismRegistry",
    "build_registry",
    # video
    "VideoPerformancePrism",
    "VideoMetadataPrism",
    # channel
    "ChannelGrowthPrism",
    "ChannelBenchmarkPrism",
    # discovery
    "TrendingTopicsPrism",
    "ContentGapPrism",
    # monetization
    "RevenueEstimatePrism",
    # seo
    "SeoAuditPrism",
    "__version__",
]