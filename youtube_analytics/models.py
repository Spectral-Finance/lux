"""Data models for the YouTube Analytics & Growth Engine.

All models are plain dataclasses with JSON-serializable fields, so they can be
stored, exchanged between agents, or dumped to any reporting backend.
"""
from __future__ import annotations

from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import List, Optional


def _iso(value) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


@dataclass
class ChannelMetrics:
    channel_id: str
    title: str
    subscriber_count: int = 0
    video_count: int = 0
    view_count: int = 0
    comment_count: int = 0
    country: str = ""
    created_at: Optional[str] = None
    fetched_at: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class VideoMetrics:
    video_id: str
    title: str
    published_at: Optional[str] = None
    view_count: int = 0
    like_count: int = 0
    comment_count: int = 0
    duration_seconds: int = 0
    category_id: str = ""
    tags: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @property
    def engagement_rate(self) -> float:
        """(likes + comments) / views — a rough audience-engagement proxy."""
        if self.view_count <= 0:
            return 0.0
        return round((self.like_count + self.comment_count) / self.view_count, 6)


@dataclass
class CommentItem:
    comment_id: str
    video_id: str
    author: str
    text: str
    like_count: int = 0
    published_at: Optional[str] = None

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class AnalyticsSnapshot:
    channel: ChannelMetrics
    videos: List[VideoMetrics] = field(default_factory=list)
    comments: List[CommentItem] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "channel": self.channel.to_dict(),
            "videos": [v.to_dict() for v in self.videos],
            "comments": [c.to_dict() for c in self.comments],
        }
