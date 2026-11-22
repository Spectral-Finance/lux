"""
Playlist-level prisms for the Lux YouTube content-intelligence suite (issue #77).

These prisms operate on ``playlists.list`` / ``playlistItems.list`` resource
shapes and produce playlist intelligence:

* :class:`PlaylistStatsPrism`    -- normalise a ``playlists.list`` item's
  statistics (item count, view count) and derive an average-views-per-item
  signal plus a 0-100 activity score.
* :class:`PlaylistOverviewPrism` -- summarise a playlist's *contents* (a list of
  ``playlistItems.list`` items, each carrying a nested video resource) into a
  ranked overview: total items, total/average views, top item and a per-item
  leaderboard.

Both are pure and deterministic; callers fetch the raw items via their client.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import round_to, safe_div, to_int

__all__ = ["PlaylistStatsPrism", "PlaylistOverviewPrism"]


def _snippet(resource: Dict[str, Any]) -> Dict[str, Any]:
    return resource.get("snippet") or {}


def _statistics(resource: Dict[str, Any]) -> Dict[str, Any]:
    return resource.get("statistics") or {}


def _content_details(resource: Dict[str, Any]) -> Dict[str, Any]:
    return resource.get("contentDetails") or {}


class PlaylistStatsPrism(Prism):
    """Normalise a ``playlists.list`` item and derive an activity signal.

    ``item_count`` comes from ``contentDetails.itemCount`` (falling back to a
    supplied value); ``view_count`` from ``statistics.viewCount``. The activity
    score (0-100) blends average views per item with raw item volume so a large,
    well-watched playlist ranks highly regardless of which single metric dominates.
    """

    name = "YouTube Playlist Stats"
    description = (
        "Normalises a playlist's item/view statistics and derives average views "
        "per item and a 0-100 activity score"
    )
    input_schema = {
        "type": "object",
        "properties": {"playlist": {"type": "object"}},
        "required": ["playlist"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "playlist_id": {"type": "string"},
            "title": {"type": "string"},
            "item_count": {"type": "integer"},
            "view_count": {"type": "integer"},
            "avg_views_per_item": {"type": "number"},
            "activity_score": {"type": "number"},
        },
        "required": ["playlist_id", "item_count", "activity_score"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        playlist = params.get_dict("playlist")
        snippet = _snippet(playlist)
        stats = _statistics(playlist)
        details = _content_details(playlist)

        item_count = to_int(details.get("itemCount"))
        if item_count == 0:
            # Fall back to an explicitly supplied count when the API omits it.
            item_count = to_int(stats.get("itemCount"))
        view_count = to_int(stats.get("viewCount"))

        avg_views = round_to(safe_div(view_count, item_count))

        avg_component = min(avg_views / 50000.0, 1.0) * 60.0
        volume_component = min(item_count / 500.0, 1.0) * 40.0
        activity_score = round_to(avg_component + volume_component, 2)

        return {
            "playlist_id": playlist.get("id", ""),
            "title": snippet.get("title", ""),
            "item_count": item_count,
            "view_count": view_count,
            "avg_views_per_item": avg_views,
            "activity_score": activity_score,
        }


class PlaylistOverviewPrism(Prism):
    """Summarise a playlist's contents into a ranked overview.

    ``items`` is a list of ``playlistItems.list`` items. Each item's video
    resource may live under ``snippet.resourceId`` (id only) or be inlined under
    a ``video`` key (a full ``videos.list`` item). The prism reports the total
    item count, aggregate + average views across items that carry statistics, the
    top item by views, and a per-item leaderboard sorted by descending views.
    """

    name = "YouTube Playlist Overview"
    description = (
        "Summarises a playlist's contents into a ranked overview: total items, "
        "aggregate/average views, the top item and a per-item leaderboard"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "items": {"type": "array", "description": "List of playlistItems.list items"},
            "limit": {"type": "integer", "description": "Max leaderboard rows (default 10)"},
        },
        "required": ["items"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "item_count": {"type": "integer"},
            "items_with_stats": {"type": "integer"},
            "total_views": {"type": "integer"},
            "avg_views_per_item": {"type": "number"},
            "top_item": {"type": "object"},
            "leaderboard": {"type": "array"},
        },
        "required": ["item_count", "leaderboard"],
    }

    @staticmethod
    def _video_of(item: Dict[str, Any]) -> Dict[str, Any]:
        """Return the inlined video resource for a playlist item, if any."""
        video = item.get("video")
        if isinstance(video, dict):
            return video
        return {}

    @staticmethod
    def _item_id(item: Dict[str, Any]) -> str:
        video = PlaylistOverviewPrism._video_of(item)
        if video.get("id"):
            return str(video.get("id"))
        resource_id = (_snippet(item).get("resourceId") or {})
        return str(resource_id.get("videoId", "") or item.get("id", ""))

    @staticmethod
    def _item_title(item: Dict[str, Any]) -> str:
        video = PlaylistOverviewPrism._video_of(item)
        if video.get("snippet", {}).get("title"):
            return str(video["snippet"]["title"])
        return str(_snippet(item).get("title", "") or "")

    @staticmethod
    def _item_views(item: Dict[str, Any]) -> int:
        video = PlaylistOverviewPrism._video_of(item)
        return to_int((video.get("statistics") or {}).get("viewCount"))

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        items = [i for i in params.get_list("items") if isinstance(i, dict)]
        limit = params.get_int("limit", 10) or 10

        rows: List[Dict[str, Any]] = []
        total_views = 0
        items_with_stats = 0
        for item in items:
            views = self._item_views(item)
            has_stats = isinstance(self._video_of(item).get("statistics"), dict)
            if has_stats:
                items_with_stats += 1
                total_views += views
            rows.append(
                {
                    "video_id": self._item_id(item),
                    "title": self._item_title(item),
                    "views": views,
                }
            )

        leaderboard = sorted(rows, key=lambda r: (-r["views"], r["video_id"]))[:limit]
        top_item = leaderboard[0] if leaderboard else {}

        return {
            "item_count": len(items),
            "items_with_stats": items_with_stats,
            "total_views": total_views,
            "avg_views_per_item": round_to(
                safe_div(total_views, items_with_stats)
            ),
            "top_item": dict(top_item),
            "leaderboard": leaderboard,
        }