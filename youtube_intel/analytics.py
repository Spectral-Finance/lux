"""
youtube_intel.analytics — analytics collection and processing.

Covers the "Analytics data collection and processing" and "Audience engagement
analysis" acceptance criteria of lux issue #69.

:class:`AnalyticsEngine` wraps a :class:`youtube_intel.core.YouTubeClient` to
pull raw video/channel data and turn it into derived metrics:

  * per-video performance (views, likes, comments, engagement rate),
  * aggregate channel statistics (totals, means, medians, view velocity),
  * audience engagement analysis (like ratio, comment ratio, engagement score),
  * time-series helpers for trend detection.

All heavy lifting is pure Python (``statistics`` module) so there are no
third-party dependencies.
"""

from __future__ import annotations

from statistics import mean, median, pstdev
from typing import Any, Dict, List, Optional, Sequence

from .core import EventEmitter, YouTubeClient

__all__ = ["AnalyticsEngine", "VideoMetrics"]


def _safe_div(a: float, b: float) -> float:
    return a / b if b else 0.0


class VideoMetrics:
    """Derived performance metrics for a single video.

    Built from a raw YouTube ``videos.list`` item via :meth:`from_item`.
    """

    __slots__ = ("video_id", "title", "views", "likes", "comments",
                 "published_at", "duration_seconds", "raw")

    def __init__(self, video_id: str, title: str, views: int, likes: int,
                 comments: int, published_at: str = "",
                 duration_seconds: float = 0.0,
                 raw: Optional[Dict[str, Any]] = None) -> None:
        self.video_id = video_id
        self.title = title
        self.views = views
        self.likes = likes
        self.comments = comments
        self.published_at = published_at
        self.duration_seconds = duration_seconds
        self.raw = raw or {}

    @classmethod
    def from_item(cls, item: Dict[str, Any]) -> "VideoMetrics":
        """Build metrics from a raw ``videos.list`` item."""
        snippet = item.get("snippet", {}) or {}
        stats = item.get("statistics", {}) or {}
        content = item.get("contentDetails", {}) or {}
        duration = _parse_iso8601_duration(content.get("duration", ""))
        return cls(
            video_id=item.get("id", ""),
            title=snippet.get("title", ""),
            views=_int(stats.get("viewCount")),
            likes=_int(stats.get("likeCount")),
            comments=_int(stats.get("commentCount")),
            published_at=snippet.get("publishedAt", ""),
            duration_seconds=duration,
            raw=item,
        )

    @property
    def engagement_rate(self) -> float:
        """(likes + comments) / views — the fraction of viewers who engage."""
        return _safe_div(self.likes + self.comments, self.views)

    @property
    def like_ratio(self) -> float:
        return _safe_div(self.likes, self.views)

    @property
    def comment_ratio(self) -> float:
        return _safe_div(self.comments, self.views)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "video_id": self.video_id,
            "title": self.title,
            "views": self.views,
            "likes": self.likes,
            "comments": self.comments,
            "engagement_rate": self.engagement_rate,
            "like_ratio": self.like_ratio,
            "comment_ratio": self.comment_ratio,
            "published_at": self.published_at,
            "duration_seconds": self.duration_seconds,
        }


def _int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


_ISO_UNITS = {"H": 3600, "M": 60, "S": 1}


def _parse_iso8601_duration(value: str) -> float:
    """Parse an ISO-8601 duration like ``PT1H2M3S`` into seconds (best effort)."""
    if not value or not value.startswith("P"):
        return 0.0
    t = value.split("T", 1)
    total = 0.0
    # date part (days) — rare for videos but handle D
    date_part = t[0][1:]
    if "D" in date_part:
        d, _, date_part = date_part.partition("D")
        total += _int(d) * 86400
    if len(t) == 2:
        time_part = t[1]
        num = ""
        for ch in time_part:
            if ch.isdigit() or ch == ".":
                num += ch
            elif ch in _ISO_UNITS:
                total += (float(num) if num else 0.0) * _ISO_UNITS[ch]
                num = ""
    return total


class AnalyticsEngine:
    """Collect and process YouTube analytics.

    Parameters
    ----------
    client:
        A configured :class:`YouTubeClient`.
    events:
        Optional shared :class:`EventEmitter`.
    """

    def __init__(self, client: YouTubeClient,
                 events: Optional[EventEmitter] = None) -> None:
        self.client = client
        self.events = events or EventEmitter()

    def _emit(self, event: str, **payload: Any) -> None:
        self.events.emit(f"Analytics.{event}", **payload)

    # ------------------------------------------------------------------ #
    # Collection
    # ------------------------------------------------------------------ #
    def fetch_video(self, video_id: str) -> VideoMetrics:
        """Fetch a single video's statistics and return :class:`VideoMetrics`."""
        data = self.client.request("GET", "videos.list", params={
            "id": video_id, "part": "snippet,statistics,contentDetails"})
        items = data.get("items", []) if isinstance(data, dict) else []
        if not items:
            from .core import NotFoundError
            raise NotFoundError(f"video {video_id} not found", status=404)
        metrics = VideoMetrics.from_item(items[0])
        self._emit("video_fetched", video_id=video_id, views=metrics.views)
        return metrics

    def fetch_videos(self, video_ids: Sequence[str]) -> List[VideoMetrics]:
        """Fetch up to 50 videos in a single batched ``videos.list`` call."""
        ids = [v for v in video_ids if v]
        out: List[VideoMetrics] = []
        for i in range(0, len(ids), 50):
            chunk = ids[i:i + 50]
            data = self.client.request("GET", "videos.list", params={
                "id": ",".join(chunk),
                "part": "snippet,statistics,contentDetails"})
            items = data.get("items", []) if isinstance(data, dict) else []
            out.extend(VideoMetrics.from_item(it) for it in items)
        self._emit("videos_fetched", count=len(out))
        return out

    def fetch_channel_videos(self, channel_id: str,
                             max_results: int = 50) -> List[VideoMetrics]:
        """Fetch a channel's uploads via its uploads playlist, then stats."""
        ch = self.client.request("GET", "channels.list", params={
            "id": channel_id, "part": "contentDetails"})
        items = ch.get("items", []) if isinstance(ch, dict) else []
        if not items:
            from .core import NotFoundError
            raise NotFoundError(f"channel {channel_id} not found", status=404)
        uploads = (items[0].get("contentDetails", {})
                   .get("relatedPlaylists", {}).get("uploads", ""))
        if not uploads:
            return []
        pl = self.client.request("GET", "playlistItems.list", params={
            "playlistId": uploads, "part": "contentDetails",
            "maxResults": min(50, max(1, max_results))})
        ids = []
        for it in pl.get("items", []) if isinstance(pl, dict) else []:
            vid = it.get("contentDetails", {}).get("videoId")
            if vid:
                ids.append(vid)
        return self.fetch_videos(ids)

    # ------------------------------------------------------------------ #
    # Processing
    # ------------------------------------------------------------------ #
    def summarize(self, metrics: Sequence[VideoMetrics]) -> Dict[str, Any]:
        """Aggregate a list of :class:`VideoMetrics` into channel statistics."""
        if not metrics:
            return {"count": 0}
        views = [m.views for m in metrics]
        eng = [m.engagement_rate for m in metrics]
        total_eng = sum(m.likes + m.comments for m in metrics)
        total_views = sum(views)
        return {
            "count": len(metrics),
            "total_views": total_views,
            "mean_views": mean(views),
            "median_views": median(views),
            "stdev_views": pstdev(views) if len(views) > 1 else 0.0,
            "total_likes": sum(m.likes for m in metrics),
            "total_comments": sum(m.comments for m in metrics),
            "mean_engagement_rate": mean(eng),
            "aggregate_engagement_rate": _safe_div(total_eng, total_views),
            "top_video": max(metrics, key=lambda m: m.views).to_dict(),
            "bottom_video": min(metrics, key=lambda m: m.views).to_dict(),
        }

    def engagement_analysis(self, metrics: Sequence[VideoMetrics]) -> Dict[str, Any]:
        """Audience engagement analysis across a set of videos."""
        if not metrics:
            return {"count": 0}
        rates = [m.engagement_rate for m in metrics]
        avg = mean(rates)
        scored = sorted(metrics, key=lambda m: m.engagement_rate, reverse=True)
        above = [m for m in metrics if m.engagement_rate > avg]
        return {
            "count": len(metrics),
            "mean_engagement_rate": avg,
            "median_engagement_rate": median(rates),
            "stdev_engagement_rate": pstdev(rates) if len(rates) > 1 else 0.0,
            "above_average_count": len(above),
            "most_engaging": scored[0].to_dict() if scored else None,
            "least_engaging": scored[-1].to_dict() if scored else None,
            "engagement_score": _engagement_score(avg),
        }

    def view_velocity(self, metrics: Sequence[VideoMetrics],
                      now_epoch: Optional[float] = None) -> List[Dict[str, Any]]:
        """Views-per-day since publish, for trend detection."""
        import time as _time
        now = now_epoch if now_epoch is not None else _time.time()
        out = []
        for m in metrics:
            age_days = _age_days(m.published_at, now)
            out.append({
                "video_id": m.video_id,
                "views": m.views,
                "age_days": age_days,
                "views_per_day": _safe_div(m.views, age_days) if age_days > 0 else float(m.views),
            })
        out.sort(key=lambda d: d["views_per_day"], reverse=True)
        return out


def _engagement_score(rate: float) -> float:
    """Map a raw engagement rate to a 0-100 score (4% ≈ 100)."""
    return max(0.0, min(100.0, rate / 0.04 * 100.0))


def _age_days(published_at: str, now_epoch: float) -> float:
    if not published_at:
        return 0.0
    import calendar
    try:
        # ISO-8601 e.g. 2026-01-01T12:00:00Z
        base = published_at.replace("Z", "")
        struct = __import__("time").strptime(base, "%Y-%m-%dT%H:%M:%S")
        published_epoch = calendar.timegm(struct)
        return max(0.0, (now_epoch - published_epoch) / 86400.0)
    except (ValueError, OverflowError):
        return 0.0