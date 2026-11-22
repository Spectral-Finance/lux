"""
Playlist prisms for the lux YouTube Prism architecture (issue #72).

Pure prisms that parse YouTube Data API v3 ``playlists`` / ``playlistItems``
resources into typed summaries. No network — callers fetch with
:class:`youtube_client.YouTubeClient` and pass the parsed ``dict`` in.

Prisms
------
* ``PlaylistResourcePrism`` — parse a ``playlists.list`` item (snippet +
  contentDetails) into a flat summary incl. item count.
* ``PlaylistItemsPrism``    — parse a ``playlistItems.list`` response into a
  normalised list of ``{video_id, title, position, published_at}`` entries.
* ``UploadsPrism``          — turn a channel's ``uploads`` playlist id + a list
  of playlistItems into a recent-uploads digest (ids + titles + count).
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput, PrismResult
from .util import to_int


class PlaylistResourcePrism(Prism):
    """Parse a ``playlists.list`` item into a flat playlist summary."""

    name = "playlist_resource"

    def run(self, inp: PrismInput) -> PrismResult:
        resource = inp.get_dict("resource")
        snippet = resource.get("snippet") or {}
        details = resource.get("contentDetails") or {}
        return PrismResult(
            data={
                "id": resource.get("id", ""),
                "title": snippet.get("title", ""),
                "description": snippet.get("description", ""),
                "channel_id": snippet.get("channelId", ""),
                "channel_title": snippet.get("channelTitle", ""),
                "published_at": snippet.get("publishedAt", ""),
                "item_count": to_int(details.get("itemCount")),
            },
            meta={"prism": self.name},
        )


class PlaylistItemsPrism(Prism):
    """Parse a ``playlistItems.list`` response into normalised entries."""

    name = "playlist_items"

    def run(self, inp: PrismInput) -> PrismResult:
        items: List[Dict[str, Any]] = inp.get_list("items")
        entries: List[Dict[str, Any]] = []
        for item in items:
            snippet = item.get("snippet") or {}
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
        return PrismResult(
            data={"entries": entries, "count": len(entries)},
            meta={"prism": self.name},
        )


class UploadsPrism(Prism):
    """Build a recent-uploads digest from playlistItems entries."""

    name = "uploads"

    def run(self, inp: PrismInput) -> PrismResult:
        uploads_playlist_id = inp.get_str("uploads_playlist_id")
        items: List[Dict[str, Any]] = inp.get_list("items")
        parsed = PlaylistItemsPrism()({"items": items}).unwrap()
        entries = parsed["entries"]
        video_ids = [e["video_id"] for e in entries if e["video_id"]]
        titles = [e["title"] for e in entries]
        return PrismResult(
            data={
                "uploads_playlist_id": uploads_playlist_id,
                "count": len(entries),
                "video_ids": video_ids,
                "titles": titles,
                "entries": entries,
            },
            meta={"prism": self.name},
        )