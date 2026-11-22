"""
Shared pure helpers for the YouTube prisms (Spectral-Finance/lux issue #72).

Deterministic, dependency-free utilities used across the concrete prisms:
number coercion (YouTube returns counts as strings), safe division, ratio
rounding, tokenisation, and a small keyword-extraction routine. No network,
no I/O — every function is a pure transform so it is trivially unit-testable.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Tuple

# Compact, dependency-free stopword set for keyword extraction.
STOPWORDS = frozenset({
    "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "for",
    "with", "is", "are", "was", "were", "be", "this", "that", "it", "as",
    "at", "by", "from", "i", "you", "your", "my", "we", "our", "how",
    "what", "why", "when", "where", "who", "which", "you", "are", "was",
    "been", "have", "has", "had", "will", "would", "could", "should", "may",
    "might", "must", "can", "get", "got", "just", "like", "love", "best",
    "top", "new", "old", "big", "small", "official", "video", "videos",
})

_WORD_RE = re.compile(r"\b\w{3,}\b")


def to_int(value: Any) -> int:
    """Coerce a value to a non-negative int (YouTube counts arrive as strings)."""
    if value is None:
        return 0
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value if value >= 0 else 0
    if isinstance(value, float):
        return int(value) if value >= 0 else 0
    if isinstance(value, str):
        try:
            n = int(value.strip())
            return n if n >= 0 else 0
        except (ValueError, TypeError):
            return 0
    return 0


def to_float(value: Any) -> float:
    """Coerce a value to a float (0.0 fallback)."""
    if isinstance(value, bool):
        return float(value)
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.strip())
        except (ValueError, TypeError):
            return 0.0
    return 0.0


def safe_div(numerator: float, denominator: float) -> float:
    """Float division that returns 0.0 when the denominator is 0."""
    if denominator == 0:
        return 0.0
    return numerator / denominator


def round_to(value: float, places: int = 2) -> float:
    """Round a float to ``places`` decimal places (banker-safe via factor)."""
    factor = 10 ** places
    return round(value * factor) / factor


def percent(numerator: float, denominator: float, places: int = 2) -> float:
    """Percentage ``numerator/denominator*100`` rounded to ``places``."""
    return round_to(safe_div(numerator, denominator) * 100.0, places)


def tokenize(text: str) -> List[str]:
    """Lowercase word tokens of length >= 3."""
    if not isinstance(text, str):
        return []
    return _WORD_RE.findall(text.lower())


def keywords(text: str, limit: int = 10) -> List[str]:
    """Extract up to ``limit`` unique, non-stopword keywords (order preserved)."""
    seen: set = set()
    out: List[str] = []
    for word in tokenize(text):
        if word in STOPWORDS or word in seen:
            continue
        seen.add(word)
        out.append(word)
        if len(out) >= limit:
            break
    return out


def top_frequency(items: List[str], limit: int = 10) -> List[Tuple[str, int]]:
    """Return the ``limit`` most frequent strings as ``(value, count)`` pairs."""
    freq: Dict[str, int] = {}
    for item in items:
        freq[item] = freq.get(item, 0) + 1
    ordered = sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))
    return ordered[:limit]