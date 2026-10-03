"""
Event Deduplicator and In-Memory Replay Buffer for NFT Sales Monitoring.
"""

from __future__ import annotations

from collections import deque
import threading
import time
from typing import Callable, Deque, Dict, List, Optional, Set

from lux.nft.types import SaleEvent


class EventDeduplicator:
    """
    High-throughput, thread-safe event deduplication engine using TTL-based LRU tracking.
    Guarantees idempotency when streaming from multiple overlapping marketplace feeds.
    """

    def __init__(self, max_capacity: int = 10000, ttl_seconds: float = 3600.0):
        self.max_capacity = max_capacity
        self.ttl_seconds = ttl_seconds
        self._seen_timestamps: Dict[str, float] = {}
        self._seen_order: Deque[str] = deque()
        self._lock = threading.RLock()

    def _generate_key(self, event: SaleEvent) -> str:
        if event.transaction_hash and event.token_id:
            return f"{event.marketplace.value}:{event.collection_address.lower()}:{event.token_id}:{event.transaction_hash.lower()}"
        return f"{event.marketplace.value}:{event.event_id}"

    def is_duplicate(self, event: SaleEvent) -> bool:
        """Checks if event has already been seen without marking it."""
        key = self._generate_key(event)
        with self._lock:
            now = time.time()
            if key in self._seen_timestamps:
                if now - self._seen_timestamps[key] < self.ttl_seconds:
                    return True
            return False

    def check_and_add(self, event: SaleEvent) -> bool:
        """
        Atomically checks if event is duplicate and marks it as seen.
        Returns True if NEW (not duplicate), False if DUPLICATE.
        """
        key = self._generate_key(event)
        with self._lock:
            now = time.time()
            # Clean expired items if capacity exceeded
            if len(self._seen_timestamps) >= self.max_capacity:
                self._prune_expired(now)

            if key in self._seen_timestamps:
                if now - self._seen_timestamps[key] < self.ttl_seconds:
                    return False  # Duplicate

            # Record new entry
            self._seen_timestamps[key] = now
            self._seen_order.append(key)
            return True

    def _prune_expired(self, current_time: float) -> None:
        """Evicts expired entries and oldest entries if capacity is reached."""
        while self._seen_order and len(self._seen_timestamps) > (self.max_capacity // 2):
            oldest_key = self._seen_order.popleft()
            ts = self._seen_timestamps.get(oldest_key)
            if ts and (current_time - ts >= self.ttl_seconds or len(self._seen_timestamps) > self.max_capacity):
                self._seen_timestamps.pop(oldest_key, None)

    def clear(self) -> None:
        with self._lock:
            self._seen_timestamps.clear()
            self._seen_order.clear()

    def size(self) -> int:
        with self._lock:
            return len(self._seen_timestamps)


class ReplayBuffer:
    """
    In-memory ring buffer holding historical events for replay, sliding window analytics,
    and fast filtering.
    """

    def __init__(self, capacity: int = 2000):
        self.capacity = capacity
        self._buffer: Deque[SaleEvent] = deque(maxlen=capacity)
        self._lock = threading.RLock()

    def append(self, event: SaleEvent) -> None:
        with self._lock:
            self._buffer.append(event)

    def extend(self, events: List[SaleEvent]) -> None:
        with self._lock:
            self._buffer.extend(events)

    def get_recent(self, limit: int = 50) -> List[SaleEvent]:
        with self._lock:
            items = list(self._buffer)
            items.sort(key=lambda e: e.timestamp, reverse=True)
            return items[:limit]

    def query(
        self,
        min_price_eth: Optional[float] = None,
        max_price_eth: Optional[float] = None,
        token_id: Optional[str] = None,
        since_timestamp: Optional[float] = None,
        predicate: Optional[Callable[[SaleEvent], bool]] = None,
    ) -> List[SaleEvent]:
        """Queries buffer with multiple filter criteria."""
        with self._lock:
            results = []
            for ev in self._buffer:
                if min_price_eth is not None and ev.price_eth < min_price_eth:
                    continue
                if max_price_eth is not None and ev.price_eth > max_price_eth:
                    continue
                if token_id is not None and str(ev.token_id) != str(token_id):
                    continue
                if since_timestamp is not None and ev.timestamp < since_timestamp:
                    continue
                if predicate is not None and not predicate(ev):
                    continue
                results.append(ev)
            results.sort(key=lambda e: e.timestamp, reverse=True)
            return results

    def clear(self) -> None:
        with self._lock:
            self._buffer.clear()

    def __len__(self) -> int:
        with self._lock:
            return len(self._buffer)
