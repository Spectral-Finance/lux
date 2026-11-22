"""
Engagement / audience prisms for the Lux YouTube content-intelligence suite
(issue #77).

These prisms reason about how an audience interacts with a batch of videos:

* :class:`EngagementTrendPrism` -- given a time-ordered batch of video resources,
  bucket them into periods and report whether engagement (likes+comments over
  views) is trending up, down or flat, plus the best/worst period.
* :class:`AudienceRetentionPrism` -- estimate relative audience retention signals
  from view/like/comment ratios across a batch, flagging which videos over- and
  under-perform the batch's own average engagement.

Both are pure and deterministic; callers fetch the raw items via their client.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import mean, percent, round_to, safe_div, to_int

__all__ = ["EngagementTrendPrism", "AudienceRetentionPrism"]


def _views(video: Dict[str, Any]) -> int:
    return to_int((video.get("statistics") or {}).get("viewCount"))


def _likes(video: Dict[str, Any]) -> int:
    return to_int((video.get("statistics") or {}).get("likeCount"))


def _comments(video: Dict[str, Any]) -> int:
    return to_int((video.get("statistics") or {}).get("commentCount"))


def _engagement_rate(video: Dict[str, Any]) -> float:
    """(likes + comments) / views * 100, or 0.0 when the video has no views."""
    views = _views(video)
    return percent(_likes(video) + _comments(video), views)


class EngagementTrendPrism(Prism):
    """Report whether engagement is trending up, down or flat across a batch.

    ``videos`` is a time-ordered list (oldest first) of video resources. The
    prism splits them into ``periods`` contiguous buckets (default 2: first half
    vs second half) and compares the mean engagement rate of each. The trend is
    ``up`` / ``down`` / ``flat`` based on the signed delta between the last and
    first period, with a small dead-band so noise reads as ``flat``.
    """

    name = "YouTube Engagement Trend"
    description = (
        "Compares engagement rates across time-ordered periods of a video batch "
        "to report an up/down/flat trend and the best/worst period"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "videos": {"type": "array", "description": "Time-ordered video items"},
            "periods": {"type": "integer", "description": "Number of buckets (default 2)"},
        },
        "required": ["videos"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_count": {"type": "integer"},
            "periods": {"type": "integer"},
            "period_rates": {"type": "array"},
            "trend": {"type": "string"},
            "delta": {"type": "number"},
            "best_period": {"type": "integer"},
            "worst_period": {"type": "integer"},
        },
        "required": ["video_count", "trend", "period_rates"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        videos = [v for v in params.get_list("videos") if isinstance(v, dict)]
        periods = params.get_int("periods", 2) or 2
        if periods < 1:
            periods = 1

        n = len(videos)
        # Contiguous buckets; distribute remainder across the earliest buckets.
        base, extra = divmod(n, periods) if periods else (n, 0)
        period_rates: List[float] = []
        idx = 0
        for p in range(periods):
            size = base + (1 if p < extra else 0)
            chunk = videos[idx: idx + size]
            idx += size
            if chunk:
                period_rates.append(
                    round_to(mean(_engagement_rate(v) for v in chunk))
                )
            else:
                period_rates.append(0.0)

        if len(period_rates) >= 2:
            delta = round_to(period_rates[-1] - period_rates[0])
        else:
            delta = 0.0

        # Dead-band: treat sub-0.05pp moves as flat so noise does not read as trend.
        if delta > 0.05:
            trend = "up"
        elif delta < -0.05:
            trend = "down"
        else:
            trend = "flat"

        best_period = period_rates.index(max(period_rates)) if period_rates else 0
        worst_period = period_rates.index(min(period_rates)) if period_rates else 0

        return {
            "video_count": n,
            "periods": periods,
            "period_rates": period_rates,
            "trend": trend,
            "delta": delta,
            "best_period": best_period,
            "worst_period": worst_period,
        }


class AudienceRetentionPrism(Prism):
    """Flag which videos over/under-perform the batch's average engagement.

    For each video the prism computes its engagement rate and compares it to the
    batch mean, producing a retention index (video_rate / batch_mean, 1.0 ==
    on par). Videos are classified ``above`` / ``below`` / ``on_par`` and sorted
    strongest-first, so a channel can see which uploads are holding attention.
    """

    name = "YouTube Audience Retention"
    description = (
        "Compares each video's engagement rate to the batch average and flags "
        "which videos over- or under-perform on audience retention"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "videos": {"type": "array", "description": "List of video items"},
            "on_par_band": {
                "type": "number",
                "description": "Fraction band around 1.0 counted as on_par (default 0.1)",
            },
        },
        "required": ["videos"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_count": {"type": "integer"},
            "batch_avg_engagement": {"type": "number"},
            "above_count": {"type": "integer"},
            "below_count": {"type": "integer"},
            "videos": {"type": "array"},
        },
        "required": ["video_count", "videos"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        videos = [v for v in params.get_list("videos") if isinstance(v, dict)]
        band = params.get_float("on_par_band", 0.1) if params.has("on_par_band") else 0.1
        if band < 0:
            band = 0.0

        rates = [_engagement_rate(v) for v in videos]
        batch_avg = round_to(mean(rates))

        rows: List[Dict[str, Any]] = []
        above = below = 0
        for video, rate in zip(videos, rates):
            index = round_to(safe_div(rate, batch_avg), 4) if batch_avg else 0.0
            if batch_avg == 0:
                classification = "on_par"
            elif index > 1.0 + band:
                classification = "above"
                above += 1
            elif index < 1.0 - band:
                classification = "below"
                below += 1
            else:
                classification = "on_par"
            rows.append(
                {
                    "video_id": video.get("id", ""),
                    "engagement_rate": round_to(rate),
                    "retention_index": index,
                    "classification": classification,
                }
            )

        rows.sort(key=lambda r: (-r["retention_index"], r["video_id"]))
        return {
            "video_count": len(videos),
            "batch_avg_engagement": batch_avg,
            "above_count": above,
            "below_count": below,
            "videos": rows,
        }