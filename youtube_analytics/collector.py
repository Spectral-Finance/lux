"""YouTube analytics data collection.

Uses the official YouTube Data API v3 when an API key is available, and falls
back to bundled sample data so the whole pipeline remains runnable and testable
without external credentials.
"""
from __future__ import annotations

import json
import os
import time
from typing import List, Optional
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .models import ChannelMetrics, VideoMetrics, CommentItem, AnalyticsSnapshot

YT_API = "https://www.googleapis.com/youtube/v3"
_SAMPLE = os.path.join(os.path.dirname(__file__), "sample_data.json")


def _get_json(url: str, retries: int = 2) -> dict:
    req = Request(url, headers={"User-Agent": "lux-youtube-analytics/1.0"})
    last = None
    for attempt in range(retries + 1):
        try:
            with urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception as exc:  # noqa: BLE001 - surface retriable network errors
            last = exc
            if attempt < retries:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"YouTube API request failed: {last}")


class YouTubeCollector:
    """Collects channel/video/comment metrics from the YouTube Data API v3."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("YOUTUBE_API_KEY")

    def fetch_channel(self, channel_id: str) -> ChannelMetrics:
        if not self.api_key:
            return self._sample().channel
        params = urlencode({
            "part": "snippet,statistics",
            "id": channel_id,
            "key": self.api_key,
        })
        data = _get_json(f"{YT_API}/channels?{params}")
        item = (data.get("items") or [{}])[0]
        sn = item.get("snippet", {})
        st = item.get("statistics", {})
        return ChannelMetrics(
            channel_id=item.get("id", channel_id),
            title=sn.get("title", ""),
            subscriber_count=int(st.get("subscriberCount", 0)),
            video_count=int(st.get("videoCount", 0)),
            view_count=int(st.get("viewCount", 0)),
            comment_count=int(st.get("commentCount", 0)),
            country=sn.get("country", ""),
            created_at=sn.get("publishedAt", ""),
            fetched_at=time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        )

    def fetch_videos(self, channel_id: str, max_results: int = 25) -> List[VideoMetrics]:
        if not self.api_key:
            return self._sample().videos[:max_results]
        videos: List[VideoMetrics] = []
        params = urlencode({
            "part": "snippet,statistics,contentDetails",
            "channelId": channel_id,
            "maxResults": min(max_results, 50),
            "order": "date",
            "key": self.api_key,
        })
        data = _get_json(f"{YT_API}/search?{params}")
        ids = [it["id"]["videoId"] for it in data.get("items", []) if it.get("id", {}).get("kind") == "youtube#video"]
        if not ids:
            return videos
        vp = urlencode({"part": "snippet,statistics,contentDetails", "id": ",".join(ids[:50]), "key": self.api_key})
        vdata = _get_json(f"{YT_API}/videos?{vp}")
        for it in vdata.get("items", []):
            sn = it.get("snippet", {})
            st = it.get("statistics", {})
            cd = it.get("contentDetails", {})
            videos.append(VideoMetrics(
                video_id=it.get("id", ""),
                title=sn.get("title", ""),
                published_at=sn.get("publishedAt", ""),
                view_count=int(st.get("viewCount", 0)),
                like_count=int(st.get("likeCount", 0)),
                comment_count=int(st.get("commentCount", 0)),
                duration_seconds=_parse_iso8601_duration(cd.get("duration", "PT0S")),
                category_id=sn.get("categoryId", ""),
                tags=sn.get("tags", []),
            ))
        return videos

    def fetch_comments(self, video_id: str, max_results: int = 20) -> List[CommentItem]:
        if not self.api_key:
            return [c for c in self._sample().comments if c.video_id == video_id][:max_results]
        params = urlencode({
            "part": "snippet",
            "videoId": video_id,
            "maxResults": min(max_results, 50),
            "key": self.api_key,
        })
        data = _get_json(f"{YT_API}/commentThreads?{params}")
        out = []
        for it in data.get("items", []):
            sn = it.get("snippet", {}).get("topLevelComment", {}).get("snippet", {})
            out.append(CommentItem(
                comment_id=it.get("id", ""),
                video_id=video_id,
                author=sn.get("authorDisplayName", ""),
                text=sn.get("textDisplay", ""),
                like_count=int(sn.get("likeCount", 0)),
                published_at=sn.get("publishedAt", ""),
            ))
        return out

    def collect(self, channel_id: str, max_videos: int = 25) -> AnalyticsSnapshot:
        channel = self.fetch_channel(channel_id)
        videos = self.fetch_videos(channel_id, max_videos)
        comments: List[CommentItem] = []
        for v in videos[:5]:
            comments.extend(self.fetch_comments(v.video_id, 5))
        return AnalyticsSnapshot(channel=channel, videos=videos, comments=comments)

    def _sample(self) -> AnalyticsSnapshot:
        with open(_SAMPLE, encoding="utf-8") as fh:
            return _load_sample(fh)


def _load_sample(fh) -> AnalyticsSnapshot:
    data = json.load(fh)
    ch = ChannelMetrics(**data["channel"])
    videos = [VideoMetrics(**v) for v in data["videos"]]
    comments = [CommentItem(**c) for c in data["comments"]]
    return AnalyticsSnapshot(channel=ch, videos=videos, comments=comments)


def _parse_iso8601_duration(duration: str) -> int:
    """Convert ISO-8601 duration (PT1H2M3S) to seconds."""
    import re
    m = re.match(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", duration or "")
    if not m:
        return 0
    h, mn, s = (int(g) if g else 0 for g in m.groups())
    return h * 3600 + mn * 60 + s
