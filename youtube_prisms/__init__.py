"""
youtube_prisms — the YouTube Prism architecture for Spectral-Finance/lux (#72).

This package is a dependency-free, deterministic Python realisation of the lux
monorepo's Prism architecture applied to the YouTube Data API v3. It is the
"prism half" of the feature set: pure decision logic with zero I/O. The I/O
half — HTTP, auth, endpoint calls — lives in the sibling ``youtube_client.py``
integration layer, which fetches resources and feeds the parsed ``dict`` into
these prisms.

Architecture
------------
* :class:`youtube_prisms.base.Prism`          — base class for every prism.
* :class:`youtube_prisms.base.PrismInput`     — typed, default-safe input view.
* :class:`youtube_prisms.base.PrismResult`    — immutable ``{ok, data, errors, meta}``.
* :class:`youtube_prisms.base.PrismRegistry`  — name -> prism dispatch.
* :func:`youtube_prisms.build_registry`       — a registry pre-loaded with every
  concrete YouTube prism, ready for ``registry.run("video_stats", params)``.

Concrete prisms
---------------
* ``channel.py``   — ``ChannelStatsPrism``, ``ChannelResourcePrism``,
  ``SearchResultPrism``, ``ChannelListPrism``.
* ``video.py``     — ``VideoStatsPrism``, ``VideoResourcePrism``,
  ``VideoListPrism`` (+ ISO-8601 duration parsing).
* ``playlist.py``  — ``PlaylistResourcePrism``, ``PlaylistItemsPrism``,
  ``UploadsPrism``.
* ``engagement.py``— ``EngagementPrism``, ``EngagementComparePrism``.
* ``keywords.py``  — ``KeywordPrism``, ``ChannelKeywordsPrism``.

Every prism is a pure ``Prism`` subclass: identical input always yields an
identical ``PrismResult`` and no sockets are ever opened. That is exactly the
lux Prism contract — deterministic logic in prisms, I/O in the client.
"""

from __future__ import annotations

from . import base, channel, engagement, keywords, playlist, util, video
from .base import Prism, PrismError, PrismInput, PrismRegistry, PrismResult
from .channel import (
    ChannelListPrism,
    ChannelResourcePrism,
    ChannelStatsPrism,
    SearchResultPrism,
)
from .engagement import EngagementComparePrism, EngagementPrism
from .keywords import ChannelKeywordsPrism, KeywordPrism
from .playlist import PlaylistItemsPrism, PlaylistResourcePrism, UploadsPrism
from .video import VideoListPrism, VideoResourcePrism, VideoStatsPrism


def build_registry() -> PrismRegistry:
    """Return a :class:`PrismRegistry` pre-loaded with every concrete prism.

    Example::

        from youtube_prisms import build_registry
        reg = build_registry()
        result = reg.run("video_stats", {"resource": video_resource})
        print(result.data["view_count"])
    """
    registry = PrismRegistry()
    for prism_cls in (
        ChannelStatsPrism,
        ChannelResourcePrism,
        SearchResultPrism,
        ChannelListPrism,
        VideoStatsPrism,
        VideoResourcePrism,
        VideoListPrism,
        PlaylistResourcePrism,
        PlaylistItemsPrism,
        UploadsPrism,
        EngagementPrism,
        EngagementComparePrism,
        KeywordPrism,
        ChannelKeywordsPrism,
    ):
        registry.register(prism_cls())
    return registry


__all__ = [
    # architecture
    "Prism",
    "PrismInput",
    "PrismResult",
    "PrismRegistry",
    "PrismError",
    "build_registry",
    # submodules
    "base",
    "channel",
    "video",
    "playlist",
    "engagement",
    "keywords",
    "util",
    # concrete prisms
    "ChannelStatsPrism",
    "ChannelResourcePrism",
    "SearchResultPrism",
    "ChannelListPrism",
    "VideoStatsPrism",
    "VideoResourcePrism",
    "VideoListPrism",
    "PlaylistResourcePrism",
    "PlaylistItemsPrism",
    "UploadsPrism",
    "EngagementPrism",
    "EngagementComparePrism",
    "KeywordPrism",
    "ChannelKeywordsPrism",
]

__version__ = "1.0.0"