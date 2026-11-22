"""
Channel-level prisms for the Lux YouTube content-intelligence suite (issue #76).

These prisms operate on ``channels.list`` resource items and produce channel
intelligence:

* :class:`ChannelGrowthPrism`     -- normalise subscriber/view/video counts and
  compute upload frequency, average views per video and a growth signal.
* :class:`ChannelBenchmarkPrism` -- compare a channel against a set of peer
  channels and report percentile-style standing on subscribers and views.

Both are pure and deterministic; callers fetch the raw items via their client.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import mean, percent, round_to, safe_div, to_int

__all__ = ["ChannelGrowthPrism", "ChannelBenchmarkPrism"]


def _snippet(channel: Dict[str, Any]) -> Dict[str, Any]:
    return channel.get("snippet") or {}


def _statistics(channel: Dict[str, Any]) -> Dict[str, Any]:
    return channel.get("statistics") or {}


class ChannelGrowthPrism(Prism):
    """Normalise channel statistics and derive growth/activity signals.

    ``hidden_subscriber_count`` is respected: when the API hides the subscriber
    count the prism reports ``subscribers_hidden`` and excludes subscriber-based
    signals rather than treating the channel as having zero subscribers.
    """

    name = "YouTube Channel Growth"
    description = (
        "Normalises channel statistics and derives upload frequency, average "
        "views per video and a 0-100 growth signal"
    )
    input_schema = {
        "type": "object",
        "properties": {"channel": {"type": "object"}},
        "required": ["channel"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "channel_id": {"type": "string"},
            "title": {"type": "string"},
            "subscribers": {"type": "integer"},
            "subscribers_hidden": {"type": "boolean"},
            "total_views": {"type": "integer"},
            "video_count": {"type": "integer"},
            "avg_views_per_video": {"type": "number"},
            "growth_signal": {"type": "number"},
        },
        "required": ["channel_id", "video_count", "growth_signal"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        channel = params.get_dict("channel")
        snippet = _snippet(channel)
        stats = _statistics(channel)

        hidden = bool(stats.get("hiddenSubscriberCount", False))
        subscribers = 0 if hidden else to_int(stats.get("subscriberCount"))
        total_views = to_int(stats.get("viewCount"))
        video_count = to_int(stats.get("videoCount"))

        avg_views = round_to(safe_div(total_views, video_count))

        # Growth signal (0-100): blend of average views per video (log-ish,
        # capped) and upload volume. Channels with hidden subscriber counts are
        # scored on views + volume only so the signal stays meaningful.
        avg_component = min(avg_views / 100000.0, 1.0) * 60.0
        volume_component = min(video_count / 1000.0, 1.0) * 40.0
        growth_signal = round_to(avg_component + volume_component, 2)

        return {
            "channel_id": channel.get("id", ""),
            "title": snippet.get("title", ""),
            "subscribers": subscribers,
            "subscribers_hidden": hidden,
            "total_views": total_views,
            "video_count": video_count,
            "avg_views_per_video": avg_views,
            "growth_signal": growth_signal,
        }


class ChannelBenchmarkPrism(Prism):
    """Benchmark a channel against a set of peer channels.

    Reports the channel's standing (rank + percentile) on subscribers and total
    views relative to ``peers`` (a list of ``channels.list`` items). Percentile
    is the fraction of peers the channel equals or beats, in ``[0, 100]``.
    """

    name = "YouTube Channel Benchmark"
    description = (
        "Benchmarks a channel against peer channels, reporting rank and "
        "percentile standing on subscribers and total views"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "channel": {"type": "object"},
            "peers": {"type": "array", "description": "List of peer channel items"},
        },
        "required": ["channel", "peers"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "channel_id": {"type": "string"},
            "peer_count": {"type": "integer"},
            "subscriber_percentile": {"type": "number"},
            "view_percentile": {"type": "number"},
            "subscriber_rank": {"type": "integer"},
            "overall_percentile": {"type": "number"},
        },
        "required": ["channel_id", "overall_percentile"],
    }

    @staticmethod
    def _percentile(value: int, others: List[int]) -> float:
        if not others:
            return 100.0
        beaten = sum(1 for other in others if value >= other)
        return round_to(safe_div(beaten, len(others)) * 100.0, 2)

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        channel = params.get_dict("channel")
        peers = [p for p in params.get_list("peers") if isinstance(p, dict)]

        stats = _statistics(channel)
        hidden = bool(stats.get("hiddenSubscriberCount", False))
        subscribers = 0 if hidden else to_int(stats.get("subscriberCount"))
        views = to_int(stats.get("viewCount"))

        peer_subs = [
            0 if _statistics(p).get("hiddenSubscriberCount")
            else to_int(_statistics(p).get("subscriberCount"))
            for p in peers
        ]
        peer_views = [to_int(_statistics(p).get("viewCount")) for p in peers]

        sub_percentile = self._percentile(subscribers, peer_subs)
        view_percentile = self._percentile(views, peer_views)
        overall = round_to(mean([sub_percentile, view_percentile]), 2)

        # Rank is 1 + number of peers strictly ahead on subscribers.
        sub_rank = 1 + sum(1 for s in peer_subs if s > subscribers)

        return {
            "channel_id": channel.get("id", ""),
            "peer_count": len(peers),
            "subscriber_percentile": sub_percentile,
            "view_percentile": view_percentile,
            "subscriber_rank": sub_rank,
            "overall_percentile": overall,
        }