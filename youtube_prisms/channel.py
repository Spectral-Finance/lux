"""
Channel prisms for the lux YouTube Prism architecture (issue #74).

Pure, deterministic prisms that turn a raw YouTube Data API v3 ``channels`` /
``search`` resource into structured intelligence. No network — callers fetch
the resource with :class:`youtube_client.YouTubeClient` and pass the parsed
``dict`` into these prisms.

Prisms
------
* ``ChannelStatsPrism``  — parse ``statistics`` (subscribers/views/video count)
  into typed ints with derived ratios.
* ``ChannelResourcePrism`` — parse a full ``channels.list`` item (snippet +
  statistics + contentDetails) into a flat summary, including the uploads
  playlist id.
* ``SearchResultPrism``  — normalise a ``search.list`` item into
  ``{kind, id, title, channel_title, published_at}`` regardless of result type.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput, PrismResult
from .util import round_to, safe_div, to_int


class ChannelStatsPrism(Prism):
    """Parse a ``channels`` resource ``statistics`` block into typed metrics."""

    name = "channel_stats"

    def run(self, inp: PrismInput) -> PrismResult:
        resource = inp.get_dict("resource")
        stats = resource.get("statistics") or {}
        snippet = resource.get("snippet") or {}

        subscriber_count = to_int(stats.get("subscriberCount"))
        view_count = to_int(stats.get("viewCount"))
        video_count = to_int(stats.get("videoCount"))
        hidden = bool(stats.get("hiddenSubscriberCount", False))

        # Average views per uploaded video — a useful content-velocity proxy.
        avg_views_per_video = round_to(safe_div(view_count, video_count), 2)

        return PrismResult(
            data={
                "channel_id": resource.get("id", ""),
                "title": snippet.get("title", ""),
                "subscriber_count": subscriber_count,
                "view_count": view_count,
                "video_count": video_count,
                "hidden_subscriber_count": hidden,
                "avg_views_per_video": avg_views_per_video,
            },
            meta={"prism": self.name},
        )


class ChannelResourcePrism(Prism):
    """Parse a full ``channels.list`` item into a flat channel summary."""

    name = "channel_resource"

    def run(self, inp: PrismInput) -> PrismResult:
        resource = inp.get_dict("resource")
        snippet = resource.get("snippet") or {}
        stats = resource.get("statistics") or {}
        details = resource.get("contentDetails") or {}
        related = details.get("relatedPlaylists") or {}

        return PrismResult(
            data={
                "id": resource.get("id", ""),
                "title": snippet.get("title", ""),
                "description": snippet.get("description", ""),
                "custom_url": snippet.get("customUrl", ""),
                "published_at": snippet.get("publishedAt", ""),
                "country": snippet.get("country", ""),
                "subscriber_count": to_int(stats.get("subscriberCount")),
                "view_count": to_int(stats.get("viewCount")),
                "video_count": to_int(stats.get("videoCount")),
                "uploads_playlist_id": related.get("uploads", ""),
            },
            meta={"prism": self.name},
        )


class SearchResultPrism(Prism):
    """Normalise a ``search.list`` item into ``{kind, id, title, ...}``.

    ``search.list`` returns ``id`` as a dict (``{"videoId": ...}`` /
    ``{"channelId": ...}`` / ``{"playlistId": ...}``); this prism flattens it
    to a ``kind`` + ``id`` pair so downstream prisms don't branch on shape.
    """

    name = "search_result"

    def run(self, inp: PrismInput) -> PrismResult:
        item = inp.get_dict("item")
        snippet = item.get("snippet") or {}
        raw_id = item.get("id") or {}

        kind = "unknown"
        resolved_id = ""
        if isinstance(raw_id, dict):
            if raw_id.get("videoId"):
                kind, resolved_id = "video", raw_id["videoId"]
            elif raw_id.get("channelId"):
                kind, resolved_id = "channel", raw_id["channelId"]
            elif raw_id.get("playlistId"):
                kind, resolved_id = "playlist", raw_id["playlistId"]
        elif isinstance(raw_id, str) and raw_id:
            kind, resolved_id = "resource", raw_id

        return PrismResult(
            data={
                "kind": kind,
                "id": resolved_id,
                "title": snippet.get("title", ""),
                "channel_title": snippet.get("channelTitle", ""),
                "published_at": snippet.get("publishedAt", ""),
                "description": snippet.get("description", ""),
            },
            meta={"prism": self.name},
        )


class ChannelListPrism(Prism):
    """Map a list of ``channels`` resources through ``ChannelStatsPrism``."""

    name = "channel_list"

    def run(self, inp: PrismInput) -> PrismResult:
        resources: List[Dict[str, Any]] = inp.get_list("resources")
        stats = ChannelStatsPrism()
        channels = [stats({"resource": r}).unwrap() for r in resources]
        return PrismResult(
            data={"channels": channels, "count": len(channels)},
            meta={"prism": self.name},
        )