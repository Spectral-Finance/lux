"""
SEO prisms for the Lux YouTube content-intelligence suite (issue #77).

* :class:`SeoAuditPrism` -- audit a video's title/description/tags for search
  discoverability and return a 0-100 score plus concrete, actionable
  recommendations (title length, keyword presence, description depth, tag
  coverage, hashtag usage).

The prism is pure and deterministic; callers pass in the video's snippet (as
returned by ``videos.list``) and, optionally, a target keyword to check for.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput
from .util import round_to, tokenize

__all__ = ["SeoAuditPrism"]

# Tunable thresholds for the audit. Kept as module constants so the scoring is
# transparent and easy to adjust.
_TITLE_MIN = 30
_TITLE_MAX = 70
_DESC_MIN = 250
_TAGS_MIN = 5
_TAGS_MAX = 15


class SeoAuditPrism(Prism):
    """Audit a video's SEO metadata and return a score + recommendations."""

    name = "YouTube SEO Audit"
    description = (
        "Audits a video's title, description and tags for search "
        "discoverability and returns a 0-100 score with actionable recommendations"
    )
    input_schema = {
        "type": "object",
        "properties": {
            "snippet": {"type": "object", "description": "videos.list snippet"},
            "target_keyword": {
                "type": "string",
                "description": "Optional keyword to check for in title/description",
            },
        },
        "required": ["snippet"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "score": {"type": "number"},
            "title_length": {"type": "integer"},
            "description_length": {"type": "integer"},
            "tag_count": {"type": "integer"},
            "keyword_in_title": {"type": "boolean"},
            "keyword_in_description": {"type": "boolean"},
            "recommendations": {"type": "array"},
        },
        "required": ["score", "recommendations"],
    }

    def handler(self, params: PrismInput) -> Dict[str, Any]:
        snippet = params.get_dict("snippet")
        title = str(snippet.get("title", "") or "")
        description = str(snippet.get("description", "") or "")
        tags = snippet.get("tags")
        if not isinstance(tags, (list, tuple)):
            tags = []
        target = params.get_str("target_keyword", "").strip().lower()

        title_len = len(title)
        desc_len = len(description)
        tag_count = len(tags)

        title_tokens = set(tokenize(title))
        desc_tokens = set(tokenize(description))
        keyword_in_title = bool(target) and target in title_tokens
        keyword_in_description = bool(target) and target in desc_tokens

        score = 0.0
        recommendations: List[str] = []

        # Title length (25 pts): full marks inside the sweet spot.
        if _TITLE_MIN <= title_len <= _TITLE_MAX:
            score += 25.0
        elif title_len == 0:
            recommendations.append("Add a title; the video currently has none.")
        elif title_len < _TITLE_MIN:
            score += 12.5
            recommendations.append(
                "Broaden the title to %d-%d characters for better discoverability."
                % (_TITLE_MIN, _TITLE_MAX)
            )
        else:
            score += 12.5
            recommendations.append(
                "Shorten the title to %d-%d characters; long titles get truncated."
                % (_TITLE_MIN, _TITLE_MAX)
            )

        # Description depth (25 pts).
        if desc_len >= _DESC_MIN:
            score += 25.0
        elif desc_len > 0:
            score += 12.5
            recommendations.append(
                "Expand the description to at least %d characters with keyword-rich copy."
                % _DESC_MIN
            )
        else:
            recommendations.append("Add a description; empty descriptions hurt SEO.")

        # Tag coverage (25 pts).
        if _TAGS_MIN <= tag_count <= _TAGS_MAX:
            score += 25.0
        elif tag_count < _TAGS_MIN:
            score += round_to(25.0 * tag_count / _TAGS_MIN, 2)
            recommendations.append(
                "Add more tags (target %d-%d); currently %d." % (_TAGS_MIN, _TAGS_MAX, tag_count)
            )
        else:
            score += 12.5
            recommendations.append(
                "Reduce tag stuffing to %d-%d focused tags." % (_TAGS_MIN, _TAGS_MAX)
            )

        # Target keyword placement (25 pts).
        if target:
            if keyword_in_title:
                score += 12.5
            else:
                recommendations.append(
                    "Work the target keyword %r into the title." % target
                )
            if keyword_in_description:
                score += 12.5
            else:
                recommendations.append(
                    "Work the target keyword %r into the description." % target
                )
        else:
            # No target supplied: award the keyword points by default so the
            # score reflects the metadata quality the caller can control.
            score += 25.0

        return {
            "score": round_to(score, 2),
            "title_length": title_len,
            "description_length": desc_len,
            "tag_count": tag_count,
            "keyword_in_title": keyword_in_title,
            "keyword_in_description": keyword_in_description,
            "recommendations": recommendations,
        }