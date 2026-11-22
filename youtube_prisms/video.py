"""
Video prisms for the lux YouTube Prism architecture (issue #74).

Pure prisms that parse a YouTube Data API v3 ``videos`` resource into typed
intelligence. No network — callers fetch the resource with
:class:`youtube_client.YouTubeClient` and pass the parsed ``dict`` in.

Prisms
------
* ``VideoStatsPrism``   — parse ``statistics`` (views/likes/comments) to ints.
* ``VideoResourcePrism``— parse a full ``videos.list`` item (snippet +
  statistics + contentDetails) into a flat summary incl. duration + category.
* ``VideoListPrism``    — map a list of video resources through
  ``VideoResourcePrism`` and aggregate totals.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput, PrismResult
from .util import round_to, safe_div, to_int

# ISO-8601 duration (PT#H#M#S) -> seconds. Pure parser, no deps.
def _iso8601_to_seconds(duration: str) -> int:
    if not isinstance(duration, str) or not duration.startswith("PT"):
        return 0
    body = duration[2:]
    seconds = 0
    num = ""
    for ch in body:
        if ch.isdigit():
            num += ch
        elif ch == "H":
            seconds += int(num or 0) * 3600
            num = ""
        elif ch == "M":
            seconds += int(num or 0) * 60
            num = ""
        elif ch == "S":
            seconds += int(num or 0)
            num = ""
    return seconds


class VideoStatsPrism(Prism):
    """Parse a ``videos`` resource ``statistics`` block into typed metrics."""

    name = "video_stats"

    def run(self, inp: PrismInput) -> PrismResult:
        resource = inp.get_dict("resource")
        stats = resource.get("statistics") or {}
        view_count = to_int(stats.get("viewCount"))
        like_count = to_int(stats.get("likeCount"))
        comment_count = to_int(stats.get("commentCount"))
        return PrismResult(
            data={
                "video_id": resource.get("id", ""),
                "view_count": view_count,
                "like_count": like_count,
                "comment_count": comment_count,
                "like_ratio": round_to(safe_div(like_count, view_count), 4),
                "comment_ratio": round_to(safe_div(comment_count, view_count), 4),
            },
            meta={"prism": self.name},
        )


class VideoResourcePrism(Prism):
    """Parse a full ``videos.list`` item into a flat video summary."""

    name = "video_resource"

    def run(self, inp: PrismInput) -> PrismResult:
        resource = inp.get_dict("resource")
        snippet = resource.get("snippet") or {}
        stats = resource.get("statistics") or {}
        details = resource.get("contentDetails") or {}

        duration = details.get("duration", "")
        duration_seconds = _iso8601_to_seconds(duration)

        return PrismResult(
            data={
                "id": resource.get("id", ""),
                "title": snippet.get("title", ""),
                "description": snippet.get("description", ""),
                "channel_id": snippet.get("channelId", ""),
                "channel_title": snippet.get("channelTitle", ""),
                "published_at": snippet.get("publishedAt", ""),
                "category_id": snippet.get("categoryId", ""),
                "tags": list(snippet.get("tags") or []),
                "duration": duration,
                "duration_seconds": duration_seconds,
                "view_count": to_int(stats.get("viewCount")),
                "like_count": to_int(stats.get("likeCount")),
                "comment_count": to_int(stats.get("commentCount")),
            },
            meta={"prism": self.name},
        )


class VideoListPrism(Prism):
    """Map a list of video resources through ``VideoResourcePrism`` + totals."""

    name = "video_list"

    def run(self, inp: PrismInput) -> PrismResult:
        resources: List[Dict[str, Any]] = inp.get_list("resources")
        prism = VideoResourcePrism()
        videos = [prism({"resource": r}).unwrap() for r in resources]
        total_views = sum(v["view_count"] for v in videos)
        total_likes = sum(v["like_count"] for v in videos)
        total_comments = sum(v["comment_count"] for v in videos)
        return PrismResult(
            data={
                "videos": videos,
                "count": len(videos),
                "total_views": total_views,
                "total_likes": total_likes,
                "total_comments": total_comments,
            },
            meta={"prism": self.name},
        )