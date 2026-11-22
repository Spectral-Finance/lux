"""
Discovery prisms for the Lux YouTube content-intelligence suite (issue #77).

These prisms turn a batch of video resources (e.g. a ``search.list`` followed by
``videos.list``, or a channel's recent uploads) into discovery intelligence:

* :class:`TrendingTopicsPrism` -- rank the topics/keywords that recur across a
  batch of recent video titles, weighted by each video's views.
* :class:`ContentGapPrism`     -- given a channel's covered topics and a target
  topic set, surface the high-value topics the channel has *not* covered.

Both are pure and deterministic; callers fetch the raw items via their client.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import keywords, round_to, safe_div, to_int, tokenize

__all__ = ["TrendingTopicsPrism", "ContentGapPrism"]


def _title(video: Dict[str, Any]) -> str:
    return (video.get("snippet") or {}).get("title", "") or ""


def _views(video: Dict[str, Any]) -> int:
    return to_int((video.get("statistics") or {}).get("viewCount"))


class TrendingTopicsPrism(Prism):
    """Rank recurring topics across a batch of videos, weighted by views.

    Each video contributes its extracted keywords; a keyword's score is the sum
    of the views of the videos it appears in. The result lists the top ``limit``
    topics with their view-weighted score and the number of videos they appear
    in, so a channel can see what themes are actually pulling attention.
    """

    name = "YouTube Trending Topics"
    description = (
        "Ranks recurring topics across a batch of videos, weighted by each "
        "video's view count, to surface what themes are pulling attention"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "videos": {"type": "array", "description": "List of video resource items"},
            "limit": {"type": "integer", "description": "Max topics to return (default 10)"},
        },
        "required": ["videos"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "video_count": {"type": "integer"},
            "topics": {"type": "array"},
        },
        "required": ["video_count", "topics"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        videos = [v for v in params.get_list("videos") if isinstance(v, dict)]
        limit = params.get_int("limit", 10) or 10

        score: Dict[str, int] = {}
        freq: Dict[str, int] = {}
        for video in videos:
            views = _views(video)
            # De-duplicate keywords within a single video so a repeated word in
            # one title does not inflate its view weighting.
            for word in set(keywords(_title(video), limit=50)):
                score[word] = score.get(word, 0) + views
                freq[word] = freq.get(word, 0) + 1

        ordered = sorted(score.items(), key=lambda kv: (-kv[1], kv[0]))[:limit]
        topics = [
            {"topic": word, "score": views, "videos": freq[word]}
            for word, views in ordered
        ]
        return {"video_count": len(videos), "topics": topics}


class ContentGapPrism(Prism):
    """Surface high-value topics a channel has not yet covered.

    ``covered`` is a list of the channel's own video titles (or topic strings);
    ``targets`` is a list of candidate topics to consider. A target is reported
    as a gap when none of its keywords appear in the channel's covered corpus.
    Each gap is scored by the target's ``weight`` (default 1.0) so callers can
    prioritise.
    """

    name = "YouTube Content Gap"
    description = (
        "Surfaces high-value topics a channel has not covered by comparing its "
        "existing titles against a candidate target topic set"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "covered": {"type": "array", "description": "Channel's existing titles/topics"},
            "targets": {"type": "array", "description": "Candidate target topics"},
        },
        "required": ["covered", "targets"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "covered_count": {"type": "integer"},
            "target_count": {"type": "integer"},
            "gaps": {"type": "array"},
            "gap_count": {"type": "integer"},
        },
        "required": ["gaps", "gap_count"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        covered = [str(c) for c in params.get_list("covered")]
        targets = params.get_list("targets")

        covered_tokens = set()
        for entry in covered:
            covered_tokens.update(tokenize(entry))

        gaps: List[Dict[str, Any]] = []
        for target in targets:
            if isinstance(target, dict):
                label = str(target.get("topic") or target.get("title") or "")
                weight = float(target.get("weight", 1.0))
            else:
                label = str(target)
                weight = 1.0
            target_tokens = set(tokenize(label))
            if not target_tokens:
                continue
            # A gap exists when the target shares no meaningful token with the
            # channel's covered corpus.
            if target_tokens.isdisjoint(covered_tokens):
                gaps.append({"topic": label, "weight": round_to(weight, 4)})

        gaps.sort(key=lambda g: (-g["weight"], g["topic"]))
        return {
            "covered_count": len(covered),
            "target_count": len(targets),
            "gaps": gaps,
            "gap_count": len(gaps),
        }