"""
Keyword / content-intelligence prisms for the lux YouTube Prism architecture
(issue #72).

Pure prisms that extract and rank keywords from video titles / descriptions.
No network — callers pass titles (fetched via
:class:`youtube_client.YouTubeClient`) in.

Prisms
------
* ``KeywordPrism``       — extract top-N keywords from a single title/text.
* ``ChannelKeywordsPrism`` — aggregate keywords across a channel's recent video
  titles into a ranked frequency table.
"""

from __future__ import annotations

from typing import Any, Dict, List

from .base import Prism, PrismInput, PrismResult
from .util import keywords, top_frequency


class KeywordPrism(Prism):
    """Extract up to ``limit`` keywords from a single piece of text."""

    name = "keywords"

    def run(self, inp: PrismInput) -> PrismResult:
        text = inp.get_str("text")
        limit = inp.get_int("limit", 10)
        kws = keywords(text, limit=limit)
        return PrismResult(
            data={"keywords": kws, "count": len(kws)},
            meta={"prism": self.name},
        )


class ChannelKeywordsPrism(Prism):
    """Aggregate keywords across a channel's recent video titles."""

    name = "channel_keywords"

    def run(self, inp: PrismInput) -> PrismResult:
        titles: List[Any] = inp.get_list("titles")
        limit = inp.get_int("limit", 10)
        all_words: List[str] = []
        for title in titles:
            all_words.extend(keywords(str(title)))
        ranked = top_frequency(all_words, limit=limit)
        return PrismResult(
            data={
                "top_keywords": [{"keyword": kw, "count": cnt} for kw, cnt in ranked],
                "unique_keywords": len({w for w in all_words}),
                "total_keywords": len(all_words),
            },
            meta={"prism": self.name},
        )