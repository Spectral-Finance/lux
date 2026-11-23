"""Simple in-memory response cache for optimisation.

A tiny thread-safe LRU-ish cache keyed by a hash of the request parameters. It
is intentionally provider-agnostic: callers cache :class:`CompletionResponse`
objects keyed by ``(provider, model, messages, params)``.
"""
from __future__ import annotations

import hashlib
import json
import threading
from collections import OrderedDict
from typing import Any, Dict, Optional, Sequence

from lux.llm.base import CompletionResponse
from lux.llm.message import Message


def make_cache_key(
    provider: str,
    model: str,
    messages: Sequence[Message],
    params: Optional[Dict[str, Any]] = None,
) -> str:
    """Build a stable cache key from the request signature."""
    payload = {
        "provider": provider,
        "model": model,
        "messages": [m.to_dict() for m in messages],
        "params": params or {},
    }
    blob = json.dumps(payload, sort_keys=True, default=str)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


class SimpleCache:
    """Thread-safe bounded cache with FIFO eviction."""

    def __init__(self, max_size: int = 128) -> None:
        self.max_size = max_size
        self._lock = threading.Lock()
        self._store: "OrderedDict[str, CompletionResponse]" = OrderedDict()
        self.hits = 0
        self.misses = 0

    def get(self, key: str) -> Optional[CompletionResponse]:
        with self._lock:
            if key in self._store:
                self.hits += 1
                self._store.move_to_end(key)
                return self._store[key]
            self.misses += 1
            return None

    def set(self, key: str, value: CompletionResponse) -> None:
        with self._lock:
            self._store[key] = value
            self._store.move_to_end(key)
            while len(self._store) > self.max_size:
                self._store.popitem(last=False)

    def clear(self) -> None:
        with self._lock:
            self._store.clear()
            self.hits = 0
            self.misses = 0

    def stats(self) -> Dict[str, float]:
        with self._lock:
            total = self.hits + self.misses
            return {
                "size": len(self._store),
                "hits": self.hits,
                "misses": self.misses,
                "hit_rate": round(self.hits / total, 4) if total else 0.0,
            }