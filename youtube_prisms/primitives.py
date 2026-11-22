"""
Parsing-primitive prisms for the Lux YouTube content-intelligence suite (issue #77).

These prisms are the *data-normalisation* layer of the architecture: each one
turns a raw YouTube Data API v3 resource (a ``channels`` / ``videos`` /
``playlists`` / ``playlistItems`` / ``search`` item, exactly as returned by the
REST endpoints) into a flat, typed ``dict`` that the higher-level intelligence
prisms (channel growth, engagement trend, SEO audit, ...) can consume without
re-parsing wire shapes.

They are deliberately numerous and small -- one prism per resource shape -- so
that every normalisation decision is individually unit-testable and auditable.
All are pure and deterministic: identical input always yields an identical
result and no socket is ever opened.

Prisms
------
* :class:`ChannelStatsPrism`     -- ``channels`` ``statistics`` -> typed metrics.
* :class:`ChannelResourcePrism`  -- full ``channels.list`` item -> flat summary.
* :class:`SearchResultPrism`     -- ``search.list`` item -> ``{kind, id, ...}``.
* :class:`ChannelListPrism`      -- list of channels -> per-channel stats list.
* :class:`VideoStatsPrism`       -- ``videos`` ``statistics`` -> typed metrics.
* :class:`VideoResourcePrism`    -- full ``videos.list`` item -> flat summary.
* :class:`VideoListPrism`        -- list of videos -> per-video list + totals.
* :class:`PlaylistResourcePrism` -- ``playlists.list`` item -> flat summary.
* :class:`PlaylistItemsPrism`    -- ``playlistItems.list`` -> normalised entries.
* :class:`UploadsPrism`          -- uploads playlist items -> recent-uploads digest.
* :class:`EngagementPrism`       -- one video's stats -> engagement rate.
* :class:`EngagementComparePrism`` -- rank videos by engagement rate.
* :class:`KeywordPrism`          -- extract top-N keywords from text.
* :class:`ChannelKeywordsPrism`  -- ranked keyword frequency across titles.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import (
    iso8601_to_seconds,
    keywords,
    percent,
    round_to,
    safe_div,
    to_int,
    top_frequency,
)

__all__ = [
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


def _snippet(resource: Dict[str, Any]) -> Dict[str, Any]:
    return resource.get("snippet") or {}


def _statistics(resource: Dict[str, Any]) -> Dict[str, Any]:
    return resource.get("statistics") or {}


def _content_details(resource: Dict[str, Any]) -> Dict[str, Any]:
    return resource.get("contentDetails") or {}


# ---------------------------------------------------------------------------
# Channel primitives
# ---------------------------------------------------------------------------
class ChannelStatsPrism(Prism):
    """Parse a ``channels`` resource ``statistics`` block into typed metrics."""

    name = "channel_stats"
    description = (
        "Parses a channels.list resource statistics block into typed subscriber/"
        "view/video counts plus average views per video"
    )
    input_schema = {
        "type": "object",
        "properties": {"resource": {"type": "object"}},
        "required": ["resource"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "channel_id": {"type": "string"},
            "title": {"type": "string"},
            "subscriber_count": {"type": "integer"},
            "view_count": {"type": "integer"},
            "video_count": {"type": "integer"},
            "hidden_subscriber_count": {"type": "boolean"},
            "avg_views_per_video": {"type": "number"},
        },
        "required": ["channel_id", "video_count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resource = params.get_dict("resource")
        stats = _statistics(resource)
        snippet = _snippet(resource)

        subscriber_count = to_int(stats.get("subscriberCount"))
        view_count = to_int(stats.get("viewCount"))
        video_count = to_int(stats.get("videoCount"))
        hidden = bool(stats.get("hiddenSubscriberCount", False))
        avg_views_per_video = round_to(safe_div(view_count, video_count), 2)

        return {
            "channel_id": resource.get("id", ""),
            "title": snippet.get("title", ""),
            "subscriber_count": subscriber_count,
            "view_count": view_count,
            "video_count": video_count,
            "hidden_subscriber_count": hidden,
            "avg_views_per_video": avg_views_per_video,
        }


class ChannelResourcePrism(Prism):
    """Parse a full ``channels.list`` item into a flat channel summary."""

    name = "channel_resource"
    description = (
        "Parses a full channels.list item (snippet + statistics + "
        "contentDetails) into a flat summary including the uploads playlist id"
    )
    input_schema = {
        "type": "object",
        "properties": {"resource": {"type": "object"}},
        "required": ["resource"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "title": {"type": "string"},
            "uploads_playlist_id": {"type": "string"},
            "subscriber_count": {"type": "integer"},
            "view_count": {"type": "integer"},
            "video_count": {"type": "integer"},
        },
        "required": ["id"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resource = params.get_dict("resource")
        snippet = _snippet(resource)
        stats = _statistics(resource)
        details = _content_details(resource)
        related = details.get("relatedPlaylists") or {}

        return {
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
        }


class SearchResultPrism(Prism):
    """Normalise a ``search.list`` item into ``{kind, id, title, ...}``.

    ``search.list`` returns ``id`` as a dict (``{"videoId": ...}`` /
    ``{"channelId": ...}`` / ``{"playlistId": ...}``); this prism flattens it to
    a ``kind`` + ``id`` pair so downstream prisms never branch on shape.
    """

    name = "search_result"
    description = (
        "Normalises a search.list item into a {kind, id, title, channel_title, "
        "published_at} record regardless of result type"
    )
    input_schema = {
        "type": "object",
        "properties": {"item": {"type": "object"}},
        "required": ["item"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "kind": {"type": "string"},
            "id": {"type": "string"},
            "title": {"type": "string"},
            "channel_title": {"type": "string"},
            "published_at": {"type": "string"},
        },
        "required": ["kind", "id"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        item = params.get_dict("item")
        snippet = _snippet(item)
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

        return {
            "kind": kind,
            "id": resolved_id,
            "title": snippet.get("title", ""),
            "channel_title": snippet.get("channelTitle", ""),
            "published_at": snippet.get("publishedAt", ""),
            "description": snippet.get("description", ""),
        }


class ChannelListPrism(Prism):
    """Map a list of ``channels`` resources through :class:`ChannelStatsPrism`."""

    name = "channel_list"
    description = (
        "Maps a list of channels.list resources through ChannelStatsPrism into "
        "a list of typed per-channel stats plus a count"
    )
    input_schema = {
        "type": "object",
        "properties": {"resources": {"type": "array"}},
        "required": ["resources"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "channels": {"type": "array"},
            "count": {"type": "integer"},
        },
        "required": ["count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resources = [r for r in params.get_list("resources") if isinstance(r, dict)]
        stats = ChannelStatsPrism()
        channels = [stats.run({"resource": r}).unwrap() for r in resources]
        return {"channels": channels, "count": len(channels)}


# ---------------------------------------------------------------------------
# Video primitives
# ---------------------------------------------------------------------------
class VideoStatsPrism(Prism):
    """Parse a ``videos`` resource ``statistics`` block into typed metrics."""

    name = "video_stats"
    description = (
        "Parses a videos.list resource statistics block into typed view/like/"
        "comment counts plus like and comment ratios"
    )
    input_schema = {
        "type": "object",
        "properties": {"resource": {"type": "object"}},
        "required": ["resource"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_id": {"type": "string"},
            "view_count": {"type": "integer"},
            "like_count": {"type": "integer"},
            "comment_count": {"type": "integer"},
            "like_ratio": {"type": "number"},
            "comment_ratio": {"type": "number"},
        },
        "required": ["video_id", "view_count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resource = params.get_dict("resource")
        stats = _statistics(resource)
        view_count = to_int(stats.get("viewCount"))
        like_count = to_int(stats.get("likeCount"))
        comment_count = to_int(stats.get("commentCount"))
        return {
            "video_id": resource.get("id", ""),
            "view_count": view_count,
            "like_count": like_count,
            "comment_count": comment_count,
            "like_ratio": round_to(safe_div(like_count, view_count), 4),
            "comment_ratio": round_to(safe_div(comment_count, view_count), 4),
        }


class VideoResourcePrism(Prism):
    """Parse a full ``videos.list`` item into a flat video summary."""

    name = "video_resource"
    description = (
        "Parses a full videos.list item (snippet + statistics + contentDetails) "
        "into a flat summary including ISO-8601 duration in seconds"
    )
    input_schema = {
        "type": "object",
        "properties": {"resource": {"type": "object"}},
        "required": ["resource"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "title": {"type": "string"},
            "duration_seconds": {"type": "integer"},
            "view_count": {"type": "integer"},
            "like_count": {"type": "integer"},
            "comment_count": {"type": "integer"},
        },
        "required": ["id"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resource = params.get_dict("resource")
        snippet = _snippet(resource)
        stats = _statistics(resource)
        details = _content_details(resource)

        duration = details.get("duration", "")
        duration_seconds = iso8601_to_seconds(duration)

        return {
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
        }


class VideoListPrism(Prism):
    """Map a list of video resources through :class:`VideoResourcePrism` + totals."""

    name = "video_list"
    description = (
        "Maps a list of videos.list resources through VideoResourcePrism and "
        "aggregates total views, likes and comments"
    )
    input_schema = {
        "type": "object",
        "properties": {"resources": {"type": "array"}},
        "required": ["resources"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "videos": {"type": "array"},
            "count": {"type": "integer"},
            "total_views": {"type": "integer"},
            "total_likes": {"type": "integer"},
            "total_comments": {"type": "integer"},
        },
        "required": ["count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resources = [r for r in params.get_list("resources") if isinstance(r, dict)]
        prism = VideoResourcePrism()
        videos = [prism.run({"resource": r}).unwrap() for r in resources]
        total_views = sum(v["view_count"] for v in videos)
        total_likes = sum(v["like_count"] for v in videos)
        total_comments = sum(v["comment_count"] for v in videos)
        return {
            "videos": videos,
            "count": len(videos),
            "total_views": total_views,
            "total_likes": total_likes,
            "total_comments": total_comments,
        }


# ---------------------------------------------------------------------------
# Playlist primitives
# ---------------------------------------------------------------------------
class PlaylistResourcePrism(Prism):
    """Parse a ``playlists.list`` item into a flat playlist summary."""

    name = "playlist_resource"
    description = (
        "Parses a playlists.list item (snippet + contentDetails) into a flat "
        "summary including the item count"
    )
    input_schema = {
        "type": "object",
        "properties": {"resource": {"type": "object"}},
        "required": ["resource"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "title": {"type": "string"},
            "channel_id": {"type": "string"},
            "item_count": {"type": "integer"},
        },
        "required": ["id"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        resource = params.get_dict("resource")
        snippet = _snippet(resource)
        details = _content_details(resource)
        return {
            "id": resource.get("id", ""),
            "title": snippet.get("title", ""),
            "description": snippet.get("description", ""),
            "channel_id": snippet.get("channelId", ""),
            "channel_title": snippet.get("channelTitle", ""),
            "published_at": snippet.get("publishedAt", ""),
            "item_count": to_int(details.get("itemCount")),
        }


class PlaylistItemsPrism(Prism):
    """Parse a ``playlistItems.list`` response into normalised entries."""

    name = "playlist_items"
    description = (
        "Parses a playlistItems.list response into normalised {video_id, title, "
        "position, published_at} entries"
    )
    input_schema = {
        "type": "object",
        "properties": {"items": {"type": "array"}},
        "required": ["items"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "entries": {"type": "array"},
            "count": {"type": "integer"},
        },
        "required": ["count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        items = [i for i in params.get_list("items") if isinstance(i, dict)]
        entries: List[Dict[str, Any]] = []
        for item in items:
            snippet = _snippet(item)
            content = item.get("contentDetails") or {}
            resource_id = snippet.get("resourceId") or {}
            entries.append(
                {
                    "video_id": content.get("videoId")
                    or resource_id.get("videoId", ""),
                    "title": snippet.get("title", ""),
                    "position": to_int(snippet.get("position")),
                    "published_at": snippet.get("publishedAt", ""),
                }
            )
        return {"entries": entries, "count": len(entries)}


class UploadsPrism(Prism):
    """Build a recent-uploads digest from playlistItems entries."""

    name = "uploads"
    description = (
        "Builds a recent-uploads digest (video ids, titles, entries, count) "
        "from a channel's uploads playlist items"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "uploads_playlist_id": {"type": "string"},
            "items": {"type": "array"},
        },
        "required": ["items"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "uploads_playlist_id": {"type": "string"},
            "count": {"type": "integer"},
            "video_ids": {"type": "array"},
            "titles": {"type": "array"},
            "entries": {"type": "array"},
        },
        "required": ["count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        uploads_playlist_id = params.get_str("uploads_playlist_id")
        items = [i for i in params.get_list("items") if isinstance(i, dict)]
        parsed = PlaylistItemsPrism().run({"items": items}).unwrap()
        entries = parsed["entries"]
        video_ids = [e["video_id"] for e in entries if e["video_id"]]
        titles = [e["title"] for e in entries]
        return {
            "uploads_playlist_id": uploads_playlist_id,
            "count": len(entries),
            "video_ids": video_ids,
            "titles": titles,
            "entries": entries,
        }


# ---------------------------------------------------------------------------
# Engagement primitives
# ---------------------------------------------------------------------------
class EngagementPrism(Prism):
    """Compute the engagement rate for a single video's stats."""

    name = "engagement"
    description = (
        "Computes engagement rate (likes + comments) / views * 100 plus like and "
        "comment ratios for one video's stats"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "stats": {"type": "object"},
            "video_id": {"type": "string"},
        },
        "required": ["stats"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_id": {"type": "string"},
            "view_count": {"type": "integer"},
            "like_count": {"type": "integer"},
            "comment_count": {"type": "integer"},
            "engagement_rate_percent": {"type": "number"},
            "like_ratio": {"type": "number"},
            "comment_ratio": {"type": "number"},
        },
        "required": ["engagement_rate_percent"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        stats = params.get_dict("stats")
        view_count = to_int(stats.get("view_count", stats.get("viewCount")))
        like_count = to_int(stats.get("like_count", stats.get("likeCount")))
        comment_count = to_int(stats.get("comment_count", stats.get("commentCount")))

        engagement_rate = percent(like_count + comment_count, view_count)
        return {
            "video_id": params.get_str("video_id", stats.get("id", "")),
            "view_count": view_count,
            "like_count": like_count,
            "comment_count": comment_count,
            "engagement_rate_percent": engagement_rate,
            "like_ratio": round_to(safe_div(like_count, view_count), 4),
            "comment_ratio": round_to(safe_div(comment_count, view_count), 4),
        }


class EngagementComparePrism(Prism):
    """Rank videos by engagement rate; report top + set average."""

    name = "engagement_compare"
    description = (
        "Ranks a list of videos by engagement rate and surfaces the top "
        "performer plus the average engagement rate across the set"
    )
    input_schema = {
        "type": "object",
        "properties": {"videos": {"type": "array"}},
        "required": ["videos"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "count": {"type": "integer"},
            "ranked": {"type": "array"},
            "top": {"type": "object"},
            "average_engagement_rate_percent": {"type": "number"},
        },
        "required": ["count", "ranked"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        videos = [v for v in params.get_list("videos") if isinstance(v, dict)]
        prism = EngagementPrism()
        scored = [
            prism.run(
                {"video_id": v.get("video_id", v.get("id", "")), "stats": v}
            ).unwrap()
            for v in videos
        ]
        scored_sorted = sorted(
            scored, key=lambda v: v["engagement_rate_percent"], reverse=True
        )
        rates = [v["engagement_rate_percent"] for v in scored]
        avg_rate = round_to(sum(rates) / len(rates), 2) if rates else 0.0
        return {
            "count": len(scored),
            "ranked": scored_sorted,
            "top": scored_sorted[0] if scored_sorted else {},
            "average_engagement_rate_percent": avg_rate,
        }


# ---------------------------------------------------------------------------
# Keyword primitives
# ---------------------------------------------------------------------------
class KeywordPrism(Prism):
    """Extract up to ``limit`` keywords from a single piece of text."""

    name = "keywords"
    description = (
        "Extracts up to a limit of unique, non-stopword keywords from a single "
        "title or description"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "text": {"type": "string"},
            "limit": {"type": "integer"},
        },
        "required": ["text"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "keywords": {"type": "array"},
            "count": {"type": "integer"},
        },
        "required": ["count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        text = params.get_str("text")
        limit = params.get_int("limit", 10)
        kws = keywords(text, limit=limit)
        return {"keywords": kws, "count": len(kws)}


class ChannelKeywordsPrism(Prism):
    """Aggregate keywords across a channel's recent video titles."""

    name = "channel_keywords"
    description = (
        "Aggregates keywords across a channel's recent video titles into a "
        "ranked frequency table"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "titles": {"type": "array"},
            "limit": {"type": "integer"},
        },
        "required": ["titles"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "top_keywords": {"type": "array"},
            "unique_keywords": {"type": "integer"},
            "total_keywords": {"type": "integer"},
        },
        "required": ["top_keywords"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        titles = params.get_list("titles")
        limit = params.get_int("limit", 10)
        all_words: List[str] = []
        for title in titles:
            all_words.extend(keywords(str(title)))
        ranked = top_frequency(all_words, limit=limit)
        return {
            "top_keywords": [{"keyword": kw, "count": cnt} for kw, cnt in ranked],
            "unique_keywords": len({w for w in all_words}),
            "total_keywords": len(all_words),
        }