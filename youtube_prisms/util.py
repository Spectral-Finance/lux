"""
Pure, deterministic helpers shared by the Lux YouTube prisms (issue #76).

Everything here is side-effect free: no network, no clock, no global state.
The helpers cover the small amount of number/text/ISO-8601 massaging that the
YouTube Data API v3 payloads routinely need (counts arrive as strings, durations
as ISO-8601, dates as RFC-3339) so the prism bodies stay focused on logic.
"""

from __future__ import annotations

import re
from typing import Any, Dict, Iterable, List, Optional, Tuple

__all__ = [
    "to_int",
    "to_float",
    "safe_div",
    "round_to",
    "percent",
    "mean",
    "median",
    "tokenize",
    "keywords",
    "top_frequency",
    "iso8601_to_seconds",
    "parse_rfc3339_year",
    "clamp",
]

# A compact, transparent English stopword set. Kept intentionally small so the
# keyword extraction is explainable and auditable (no opaque model).
_STOPWORDS = frozenset(
    {
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "for",
        "with", "is", "are", "was", "were", "be", "been", "being", "this",
        "that", "these", "those", "it", "its", "as", "at", "by", "from", "i",
        "you", "your", "my", "me", "we", "us", "our", "so", "if", "do", "does",
        "did", "not", "no", "yes", "how", "what", "when", "where", "why",
        "which", "who", "can", "could", "will", "would", "should", "vs",
        "via", "out", "up", "new", "video", "videos", "http", "https",
    }
)

_WORD_RE = re.compile(r"[a-z0-9']+")
_ISO8601_RE = re.compile(
    r"^P(?:(?P<days>\d+)D)?"
    r"(?:T(?:(?P<hours>\d+)H)?(?:(?P<minutes>\d+)M)?(?:(?P<seconds>\d+(?:\.\d+)?)S)?)?$"
)


def to_int(value: Any, default: int = 0) -> int:
    """Coerce ``value`` to ``int`` (YouTube returns counts as strings)."""
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return int(value)
    try:
        return int(value)
    except (TypeError, ValueError):
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return default


def to_float(value: Any, default: float = 0.0) -> float:
    """Coerce ``value`` to ``float``."""
    if value is None or value == "":
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def safe_div(numerator: float, denominator: float, default: float = 0.0) -> float:
    """Divide, returning ``default`` when the denominator is zero."""
    if not denominator:
        return default
    return numerator / denominator


def round_to(value: float, digits: int = 4) -> float:
    """Round ``value`` to ``digits`` decimal places (returns a float)."""
    return round(float(value), digits)


def percent(part: float, whole: float, digits: int = 4) -> float:
    """Return ``part / whole * 100`` rounded, or ``0.0`` when ``whole`` is 0."""
    return round_to(safe_div(part, whole) * 100.0, digits)


def mean(values: Iterable[float]) -> float:
    """Arithmetic mean of ``values`` (``0.0`` for an empty sequence)."""
    seq = list(values)
    if not seq:
        return 0.0
    return sum(seq) / len(seq)


def median(values: Iterable[float]) -> float:
    """Median of ``values`` (``0.0`` for an empty sequence)."""
    seq = sorted(values)
    n = len(seq)
    if n == 0:
        return 0.0
    mid = n // 2
    if n % 2 == 1:
        return float(seq[mid])
    return (seq[mid - 1] + seq[mid]) / 2.0


def clamp(value: float, low: float, high: float) -> float:
    """Clamp ``value`` into the inclusive range ``[low, high]``."""
    return max(low, min(high, value))


def tokenize(text: str) -> List[str]:
    """Lowercase ``text`` and split into word tokens."""
    if not text:
        return []
    return _WORD_RE.findall(text.lower())


def keywords(text: str, limit: int = 10, min_len: int = 3) -> List[str]:
    """Extract the top ``limit`` keywords from ``text`` by frequency.

    Stopwords and tokens shorter than ``min_len`` are dropped. Ties break
    alphabetically so the result is fully deterministic.
    """
    counts: Dict[str, int] = {}
    for tok in tokenize(text):
        if len(tok) < min_len or tok in _STOPWORDS:
            continue
        counts[tok] = counts.get(tok, 0) + 1
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    return [word for word, _ in ordered[:limit]]


def top_frequency(items: Iterable[str], limit: int = 10) -> List[Tuple[str, int]]:
    """Return ``(token, count)`` pairs sorted by descending count then alpha."""
    counts: Dict[str, int] = {}
    for item in items:
        for tok in tokenize(item):
            if len(tok) < 3 or tok in _STOPWORDS:
                continue
            counts[tok] = counts.get(tok, 0) + 1
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    return ordered[:limit]


def iso8601_to_seconds(duration: Optional[str]) -> int:
    """Convert an ISO-8601 duration (e.g. ``PT1H2M3S``) to whole seconds.

    Returns ``0`` for ``None``/empty/unparseable input. Handles days, hours,
    minutes and (fractional) seconds; YouTube uses this for ``contentDetails``
    durations.
    """
    if not duration:
        return 0
    match = _ISO8601_RE.match(duration.strip())
    if not match:
        return 0
    parts = match.groupdict()
    days = to_int(parts.get("days"))
    hours = to_int(parts.get("hours"))
    minutes = to_int(parts.get("minutes"))
    seconds = to_float(parts.get("seconds"))
    return int(days * 86400 + hours * 3600 + minutes * 60 + seconds)


def parse_rfc3339_year(timestamp: Optional[str]) -> Optional[int]:
    """Extract the 4-digit year from an RFC-3339 timestamp, or ``None``."""
    if not timestamp or len(timestamp) < 4:
        return None
    head = timestamp[:4]
    if head.isdigit():
        return int(head)
    return None