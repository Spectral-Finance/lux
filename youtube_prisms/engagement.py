"""
Engagement prisms for the lux YouTube Prism architecture (issue #72).

Pure prisms that compute engagement intelligence from already-parsed video
stats. No network — callers fetch stats with
:class:`youtube_client.YouTubeClient` (or reuse ``VideoStatsPrism``) and pass
the result in.

Prisms
------
* ``EngagementPrism``      — compute engagement rate
  ``(likes + comments) / views * 100`` plus like/comment ratios for one video.
* ``EngagementComparePrism`` — rank a list of videos by engagement rate and
  surface the top performer + the average across the set.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput, PrismResult
from .util import percent, round_to, safe_div, to_int


class EngagementPrism(Prism):
    """Compute the engagement rate for a single video's stats."""

    name = "engagement"

    def run(self, inp: PrismInput) -> PrismResult:
        stats = inp.get_dict("stats")
        view_count = to_int(stats.get("view_count", stats.get("viewCount")))
        like_count = to_int(stats.get("like_count", stats.get("likeCount")))
        comment_count = to_int(stats.get("comment_count", stats.get("commentCount")))

        engagement_rate = percent(like_count + comment_count, view_count)
        return PrismResult(
            data={
                "video_id": inp.get_str("video_id", stats.get("id", "")),
                "view_count": view_count,
                "like_count": like_count,
                "comment_count": comment_count,
                "engagement_rate_percent": engagement_rate,
                "like_ratio": round_to(safe_div(like_count, view_count), 4),
                "comment_ratio": round_to(safe_div(comment_count, view_count), 4),
            },
            meta={"prism": self.name},
        )


class EngagementComparePrism(Prism):
    """Rank videos by engagement rate; report top + set average."""

    name = "engagement_compare"

    def run(self, inp: PrismInput) -> PrismResult:
        videos: List[Dict[str, Any]] = inp.get_list("videos")
        prism = EngagementPrism()
        scored = [prism({"video_id": v.get("video_id", v.get("id", "")), "stats": v}).unwrap()
                  for v in videos]
        scored_sorted = sorted(
            scored, key=lambda v: v["engagement_rate_percent"], reverse=True
        )
        rates = [v["engagement_rate_percent"] for v in scored]
        avg_rate = round_to(sum(rates) / len(rates), 2) if rates else 0.0
        return PrismResult(
            data={
                "count": len(scored),
                "ranked": scored_sorted,
                "top": scored_sorted[0] if scored_sorted else {},
                "average_engagement_rate_percent": avg_rate,
            },
            meta={"prism": self.name},
        )