"""
Video-level prisms for the Lux YouTube content-intelligence suite (issue #75).

These prisms operate on a single ``videos.list`` resource item (the dict shape
returned by the YouTube Data API v3) and produce structured intelligence:

* :class:`VideoPerformancePrism` -- normalise raw stats + compute engagement
  rates, like/comment ratios and a 0-100 performance score.
* :class:`VideoMetadataPrism`    -- extract clean, flattened metadata
  (title, tags, duration, published year, category) for downstream indexing.

Both are pure and deterministic; callers fetch the raw item via their client.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import (
    iso8601_to_seconds,
    parse_rfc3339_year,
    percent,
    round_to,
    safe_div,
    to_float,
    to_int,
)

__all__ = ["VideoPerformancePrism", "VideoMetadataPrism"]


def _snippet(video: Dict[str, Any]) -> Dict[str, Any]:
    return video.get("snippet") or {}


def _statistics(video: Dict[str, Any]) -> Dict[str, Any]:
    return video.get("statistics") or {}


def _content_details(video: Dict[str, Any]) -> Dict[str, Any]:
    return video.get("contentDetails") or {}


class VideoPerformancePrism(Prism):
    """Compute engagement metrics and a 0-100 performance score for a video.

    Input ``video`` is a ``videos.list`` item. The score blends normalised
    engagement rate (likes+comments over views) with like ratio so that a video
    with strong interaction relative to reach ranks highly regardless of raw
    view count.
    """

    name = "YouTube Video Performance"
    description = (
        "Computes engagement rates, like/comment ratios and a 0-100 performance "
        "score for a single YouTube video resource"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "video": {"type": "object", "description": "A videos.list resource item"},
            "benchmark_views": {
                "type": "integer",
                "description": "Optional view count treated as a 100% score reference",
            },
        },
        "required": ["video"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_id": {"type": "string"},
            "views": {"type": "integer"},
            "likes": {"type": "integer"},
            "comments": {"type": "integer"},
            "engagement_rate": {"type": "number"},
            "like_ratio": {"type": "number"},
            "comment_ratio": {"type": "number"},
            "performance_score": {"type": "number"},
        },
        "required": ["video_id", "views", "performance_score"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        video = params.get_dict("video")
        stats = _statistics(video)
        views = to_int(stats.get("viewCount"))
        likes = to_int(stats.get("likeCount"))
        comments = to_int(stats.get("commentCount"))

        engagement_rate = percent(likes + comments, views)
        like_ratio = round_to(safe_div(likes, views) * 100.0)
        comment_ratio = round_to(safe_div(comments, views) * 100.0)

        # Performance score: 70% engagement-rate component (capped at 10% ER =>
        # full marks) + 30% like-ratio component (capped at 10% like ratio).
        er_component = min(engagement_rate / 10.0, 1.0) * 70.0
        like_component = min(like_ratio / 10.0, 1.0) * 30.0
        score = round_to(er_component + like_component, 2)

        return {
            "video_id": video.get("id", ""),
            "views": views,
            "likes": likes,
            "comments": comments,
            "engagement_rate": engagement_rate,
            "like_ratio": like_ratio,
            "comment_ratio": comment_ratio,
            "performance_score": score,
        }


class VideoMetadataPrism(Prism):
    """Flatten a ``videos.list`` item into clean, indexable metadata."""

    name = "YouTube Video Metadata"
    description = (
        "Extracts flattened, indexable metadata (title, tags, duration, "
        "published year, category, language) from a videos.list resource item"
    )
    input_schema = {
        "type": "object",
        "properties": {"video": {"type": "object"}},
        "required": ["video"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "tags": {"type": "array"},
            "duration_seconds": {"type": "integer"},
            "published_year": {"type": "integer"},
            "category_id": {"type": "string"},
            "channel_id": {"type": "string"},
            "default_language": {"type": "string"},
        },
        "required": ["video_id", "title"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        video = params.get_dict("video")
        snippet = _snippet(video)
        details = _content_details(video)
        tags = snippet.get("tags")
        if not isinstance(tags, (list, tuple)):
            tags = []

        return {
            "video_id": video.get("id", ""),
            "title": snippet.get("title", ""),
            "description": snippet.get("description", ""),
            "tags": [str(t) for t in tags],
            "duration_seconds": iso8601_to_seconds(details.get("duration")),
            "published_year": parse_rfc3339_year(snippet.get("publishedAt")),
            "category_id": str(snippet.get("categoryId", "")),
            "channel_id": snippet.get("channelId", ""),
            "default_language": snippet.get("defaultLanguage")
            or snippet.get("defaultAudioLanguage", ""),
        }