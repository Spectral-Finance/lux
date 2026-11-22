"""
youtube_intel.optimizer — content optimization and recommendation.

Covers the "Title and thumbnail optimization", "Tag optimization", "Description
generation", "Content recommendation engine" and "Trending topic analysis"
acceptance criteria of lux issue #69.

All components are pure Python and deterministic:

  * :class:`TitleOptimizer`      — score titles (length, keyword power, number
    hooks, sentiment-ish caps) and suggest improved variants.
  * :class:`ThumbnailOptimizer`  — score thumbnail "metadata" (we can't see the
    image, but we can reason about title contrast, face/brand heuristics passed
    in as features) and recommend A/B variants.
  * :class:`TagOptimizer`        — extract, rank, and expand tags from text using
    a frequency + length heuristic, with dedupe and YouTube's 500-char budget.
  * :class:`DescriptionGenerator` — assemble an SEO description from title, tags,
    transcript keywords, and a call-to-action.
  * :class:`RecommendationEngine` — "related content" recommender using TF-IDF-ish
    cosine similarity over an in-memory corpus.
  * :class:`TrendingTopicAnalyzer` — mine trending hashtags/keywords from a corpus
    of recent titles/descriptions with growth scoring.
"""

from __future__ import annotations

import math
import re
from collections import Counter
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

__all__ = [
    "TitleOptimizer",
    "ThumbnailOptimizer",
    "TagOptimizer",
    "DescriptionGenerator",
    "RecommendationEngine",
    "TrendingTopicAnalyzer",
]

_WORD_RE = re.compile(r"[a-z0-9']+")
_STOPWORDS = frozenset({
    "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "for",
    "with", "is", "are", "was", "were", "be", "this", "that", "it", "as",
    "at", "by", "from", "your", "you", "how", "what", "why", "i",
})

#: Words that tend to earn clicks (heuristic "power words").
_POWER_WORDS = frozenset({
    "free", "new", "best", "top", "ultimate", "secret", "proven", "fast",
    "easy", "complete", "guide", "how", "tips", "tricks", "review", "vs",
    "insane", "powerful", "simple", "instant", "exclusive", "revealed",
})


def _tokenize(text: str) -> List[str]:
    return _WORD_RE.findall(text.lower())


def _content_words(text: str) -> List[str]:
    return [w for w in _tokenize(text) if w not in _STOPWORDS and len(w) > 2]


# --------------------------------------------------------------------------- #
# Title optimizer
# --------------------------------------------------------------------------- #
class TitleOptimizer:
    """Score and improve YouTube video titles.

    A good title (per common creator guidance) is 40-70 characters, front-loads
    the keyword, contains a power word or number, and reads cleanly. We encode
    those heuristics into a 0-100 score and generate improved variants.
    """

    MIN_LEN, MAX_LEN = 40, 70

    def score(self, title: str, keyword: Optional[str] = None) -> Dict[str, Any]:
        title = title or ""
        n = len(title)
        words = _tokenize(title)
        reasons: List[str] = []

        # length score (peak inside [40, 70])
        if n == 0:
            length_score = 0.0
            reasons.append("empty title")
        elif self.MIN_LEN <= n <= self.MAX_LEN:
            length_score = 100.0
        elif n < self.MIN_LEN:
            length_score = max(0.0, n / self.MIN_LEN * 100.0)
            reasons.append("too short")
        else:
            length_score = max(0.0, 100.0 - (n - self.MAX_LEN) * 2.0)
            reasons.append("too long")

        # power word
        has_power = any(w in _POWER_WORDS for w in words)
        power_score = 100.0 if has_power else 40.0
        if has_power:
            reasons.append("has power word")

        # number hook
        has_number = bool(re.search(r"\d", title))
        number_score = 100.0 if has_number else 50.0
        if has_number:
            reasons.append("has number")

        # keyword front-loading
        keyword_score = 50.0
        if keyword:
            kl = keyword.lower()
            if title.lower().startswith(kl):
                keyword_score = 100.0
                reasons.append("keyword front-loaded")
            elif kl in title.lower():
                keyword_score = 75.0
                reasons.append("keyword present")

        # caps ratio (some caps ok, all caps bad)
        letters = [c for c in title if c.isalpha()]
        caps_ratio = (sum(1 for c in letters if c.isupper()) / len(letters)
                      if letters else 0.0)
        caps_score = 100.0 if caps_ratio <= 0.4 else max(0.0, 100.0 - caps_ratio * 100.0)

        weights = {"length": 0.30, "power": 0.20, "number": 0.15,
                   "keyword": 0.20, "caps": 0.15}
        scores = {"length": length_score, "power": power_score,
                  "number": number_score, "keyword": keyword_score,
                  "caps": caps_score}
        total = sum(scores[k] * weights[k] for k in weights)
        return {
            "title": title,
            "score": round(total, 1),
            "length": n,
            "components": {k: round(v, 1) for k, v in scores.items()},
            "reasons": reasons,
        }

    def suggest(self, title: str, keyword: Optional[str] = None,
                top_k: int = 3) -> List[Dict[str, Any]]:
        """Generate improved title variants ranked by score."""
        candidates: List[str] = []
        base = title.strip()
        kw = keyword or (self._top_keyword(base))
        # Variant builders
        if not re.search(r"\d", base):
            candidates.append(f"{base}: 7 Tips That Work")
            candidates.append(f"7 {kw.title()} Tips You Need in 2026")
        if not any(w in _POWER_WORDS for w in _tokenize(base)):
            candidates.append(f"{base} — The Ultimate Guide")
            candidates.append(f"{base}: A Proven, Simple Approach")
        if keyword and not base.lower().startswith(keyword.lower()):
            candidates.append(f"{keyword.title()} — {base}")
        candidates.append(base)  # always include original
        # de-dup preserving order
        seen = set()
        uniq = []
        for c in candidates:
            if c not in seen:
                seen.add(c)
                uniq.append(c)
        scored = [self.score(c, keyword) for c in uniq]
        scored.sort(key=lambda d: d["score"], reverse=True)
        return scored[:top_k]

    @staticmethod
    def _top_keyword(title: str) -> str:
        words = _content_words(title)
        return Counter(words).most_common(1)[0][0] if words else "video"


# --------------------------------------------------------------------------- #
# Thumbnail optimizer
# --------------------------------------------------------------------------- #
class ThumbnailOptimizer:
    """Score thumbnail *metadata* and recommend A/B variants.

    We cannot inspect pixels, but creators can pass simple boolean/number
    features describing a thumbnail (has_face, has_text, text_word_count,
    contrast, brightness, has_brand). This scores those and suggests changes.
    """

    def score(self, features: Dict[str, Any]) -> Dict[str, Any]:
        f = {
            "has_face": bool(features.get("has_face", False)),
            "has_text": bool(features.get("has_text", False)),
            "text_word_count": int(features.get("text_word_count", 0)),
            "contrast": float(features.get("contrast", 0.5)),
            "brightness": float(features.get("brightness", 0.5)),
            "has_brand": bool(features.get("has_brand", False)),
        }
        score = 0.0
        reasons: List[str] = []
        score += 25.0 if f["has_face"] else 0.0
        if f["has_face"]:
            reasons.append("face present (+)")
        # text: 2-5 words ideal
        tw = f["text_word_count"]
        if 2 <= tw <= 5:
            score += 25.0
            reasons.append("text length ideal")
        elif f["has_text"]:
            score += 10.0
            reasons.append("text present but word count suboptimal")
        # contrast: higher is better up to a point
        score += min(25.0, f["contrast"] * 25.0)
        # brightness near 0.5 ideal
        score += max(0.0, 25.0 - abs(f["brightness"] - 0.5) * 50.0)
        if f["has_brand"]:
            score += 10.0
        return {
            "score": round(min(100.0, score), 1),
            "features": f,
            "reasons": reasons,
        }

    def suggest(self, features: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Return ranked thumbnail variants (original + tweaks)."""
        variants = [dict(features)]
        if not features.get("has_face"):
            v = dict(features); v["has_face"] = True; variants.append(v)
        if not features.get("has_text"):
            v = dict(features); v["has_text"] = True; v["text_word_count"] = 3
            variants.append(v)
        elif not (2 <= int(features.get("text_word_count", 0)) <= 5):
            v = dict(features); v["text_word_count"] = 3; variants.append(v)
        if float(features.get("contrast", 0.5)) < 0.6:
            v = dict(features); v["contrast"] = 0.7; variants.append(v)
        scored = [self.score(v) for v in variants]
        scored.sort(key=lambda d: d["score"], reverse=True)
        return scored


# --------------------------------------------------------------------------- #
# Tag optimizer
# --------------------------------------------------------------------------- #
class TagOptimizer:
    """Extract, rank, and expand YouTube tags from text.

    YouTube allows up to 500 characters of tags. We rank candidate tags by a
    frequency + length + specificity heuristic and pack them within budget.
    """

    MAX_TOTAL_CHARS = 500

    def __init__(self, max_tags: int = 15) -> None:
        self.max_tags = max_tags

    def extract(self, text: str, keyword: Optional[str] = None) -> List[str]:
        """Return ranked single-word tags from ``text``."""
        counts = Counter(_content_words(text))
        if keyword:
            for w in _content_words(keyword):
                counts[w] += 5  # boost the target keyword
        # score = freq * length-weight
        scored: List[Tuple[float, str]] = []
        for word, freq in counts.items():
            length_w = min(len(word), 12) / 12.0
            scored.append((freq * (0.5 + length_w), word))
        scored.sort(reverse=True)
        return [w for _, w in scored]

    def expand(self, text: str, keyword: Optional[str] = None) -> List[str]:
        """Extract tags and add common long-tail phrase variants."""
        base = self.extract(text, keyword)
        kw = keyword or (base[0] if base else "")
        phrases: List[str] = []
        if kw:
            phrases = [kw, f"{kw} tutorial", f"{kw} tips", f"how to {kw}",
                       f"{kw} 2026", f"best {kw}", f"{kw} guide"]
        combined: List[str] = []
        seen = set()
        for t in phrases + base:
            if t and t not in seen:
                seen.add(t)
                combined.append(t)
        return combined

    def optimize(self, text: str, keyword: Optional[str] = None) -> Dict[str, Any]:
        """Return a budget-aware tag set plus the serialized tag string."""
        tags = self.expand(text, keyword)
        packed: List[str] = []
        total = 0
        for t in tags:
            if len(packed) >= self.max_tags:
                break
            add = len(t) + (1 if packed else 0)
            if total + add > self.MAX_TOTAL_CHARS:
                break
            packed.append(t)
            total += add
        return {
            "tags": packed,
            "tag_string": ", ".join(packed),
            "char_count": total,
            "count": len(packed),
        }


# --------------------------------------------------------------------------- #
# Description generator
# --------------------------------------------------------------------------- #
class DescriptionGenerator:
    """Assemble an SEO-friendly description from title, tags, and keywords."""

    def __init__(self, channel_name: str = "the channel",
                 call_to_action: str = "Subscribe for more videos like this!",
                 max_keywords: int = 8) -> None:
        self.channel_name = channel_name
        self.call_to_action = call_to_action
        self.max_keywords = max_keywords

    def generate(self, title: str, tags: Optional[Sequence[str]] = None,
                 transcript: str = "", include_time: bool = False) -> Dict[str, Any]:
        tags = list(tags or [])
        keywords = self._keywords(title, transcript)
        lines: List[str] = []
        # Hook line
        lines.append(title.strip() or "Video")
        lines.append("")
        # Body paragraph weaving keywords
        if keywords:
            lines.append(
                "In this video we cover " +
                ", ".join(keywords[:self.max_keywords]) + ".")
            lines.append("")
        if transcript:
            snippet = transcript.strip()
            if len(snippet) > 240:
                snippet = snippet[:240].rsplit(" ", 1)[0] + "..."
            lines.append(snippet)
            lines.append("")
        # Tags line
        if tags:
            lines.append("Tags: " + ", ".join(tags))
            lines.append("")
        # CTA
        lines.append(self.call_to_action)
        description = "\n".join(lines).strip()
        return {
            "description": description,
            "keywords": keywords[:self.max_keywords],
            "char_count": len(description),
        }

    def _keywords(self, title: str, transcript: str) -> List[str]:
        words = _content_words(title + " " + transcript)
        return [w for w, _ in Counter(words).most_common(self.max_keywords)]


# --------------------------------------------------------------------------- #
# Recommendation engine (TF-IDF cosine similarity)
# --------------------------------------------------------------------------- #
class RecommendationEngine:
    """Content-based recommender over an in-memory corpus of video dicts.

    Each item needs at least a ``video_id`` and some text (``title`` +
    optional ``tags``/``description``). Similarity is TF-IDF cosine, computed
    with pure-Python math.
    """

    def __init__(self) -> None:
        self._items: List[Dict[str, Any]] = []
        self._vectors: List[Dict[str, float]] = []
        self._idf: Dict[str, float] = {}
        self._fitted = False

    def _doc_text(self, item: Dict[str, Any]) -> str:
        parts = [str(item.get("title", ""))]
        tags = item.get("tags") or []
        if isinstance(tags, (list, tuple)):
            parts.extend(str(t) for t in tags)
        parts.append(str(item.get("description", "")))
        return " ".join(parts)

    def fit(self, items: Sequence[Dict[str, Any]]) -> "RecommendationEngine":
        self._items = list(items)
        docs = [_tokenize(self._doc_text(it)) for it in self._items]
        n_docs = len(docs) or 1
        # document frequency
        df: Counter = Counter()
        for doc in docs:
            for term in set(doc):
                df[term] += 1
        self._idf = {t: math.log((n_docs + 1) / (c + 1)) + 1.0
                     for t, c in df.items()}
        self._vectors = [self._tfidf(doc) for doc in docs]
        self._fitted = True
        return self

    def _tfidf(self, doc: List[str]) -> Dict[str, float]:
        if not doc:
            return {}
        counts = Counter(doc)
        total = len(doc)
        vec = {}
        for term, c in counts.items():
            tf = c / total
            vec[term] = tf * self._idf.get(term, 1.0)
        norm = math.sqrt(sum(v * v for v in vec.values())) or 1.0
        return {t: v / norm for t, v in vec.items()}

    @staticmethod
    def _cosine(a: Dict[str, float], b: Dict[str, float]) -> float:
        if not a or not b:
            return 0.0
        small, large = (a, b) if len(a) < len(b) else (b, a)
        return sum(v * large.get(k, 0.0) for k, v in small.items())

    def recommend(self, video_id: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """Return the ``top_k`` most similar items to ``video_id``."""
        if not self._fitted:
            raise ValueError("engine is not fitted")
        idx = next((i for i, it in enumerate(self._items)
                    if it.get("video_id") == video_id), None)
        if idx is None:
            return []
        base = self._vectors[idx]
        scored = []
        for i, it in enumerate(self._items):
            if i == idx:
                continue
            sim = self._cosine(base, self._vectors[i])
            scored.append({"video_id": it.get("video_id"),
                           "title": it.get("title", ""),
                           "similarity": round(sim, 4)})
        scored.sort(key=lambda d: d["similarity"], reverse=True)
        return scored[:top_k]


# --------------------------------------------------------------------------- #
# Trending topic analyzer
# --------------------------------------------------------------------------- #
class TrendingTopicAnalyzer:
    """Mine trending keywords/hashtags from a corpus of recent titles.

    ``analyze`` accepts an iterable of ``(text, timestamp)`` or plain strings and
    returns ranked topics with a growth score that rewards frequency and
    recency. Pure Python.
    """

    def __init__(self, decay_half_life: float = 7.0) -> None:
        self.decay_half_life = decay_half_life

    def analyze(self, corpus: Iterable[Any],
                top_k: int = 10) -> List[Dict[str, Any]]:
        import time as _time
        now = _time.time()
        weighted: Counter = Counter()
        raw: Counter = Counter()
        for entry in corpus:
            if isinstance(entry, (tuple, list)) and len(entry) == 2:
                text, ts = entry
            else:
                text, ts = entry, now
            try:
                age_days = max(0.0, (now - float(ts)) / 86400.0)
            except (TypeError, ValueError):
                age_days = 0.0
            recency = 0.5 ** (age_days / self.decay_half_life) \
                if self.decay_half_life > 0 else 1.0
            for word in set(_content_words(str(text))):
                raw[word] += 1
                weighted[word] += recency
        topics = []
        for word, wsum in weighted.items():
            topics.append({
                "topic": word,
                "frequency": raw[word],
                "growth_score": round(wsum, 4),
            })
        topics.sort(key=lambda d: (d["growth_score"], d["frequency"]),
                    reverse=True)
        return topics[:top_k]

    def hashtags(self, corpus: Iterable[Any],
                 top_k: int = 10) -> List[str]:
        """Extract trending ``#hashtags`` from raw text entries."""
        counts: Counter = Counter()
        for entry in corpus:
            text = entry[0] if isinstance(entry, (tuple, list)) and len(entry) == 2 else entry
            for m in re.findall(r"#(\w+)", str(text)):
                counts[m.lower()] += 1
        return [f"#{tag}" for tag, _ in counts.most_common(top_k)]