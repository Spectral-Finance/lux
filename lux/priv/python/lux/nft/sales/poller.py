"""
Sales Stream Poller and Event Dispatcher for NFT Marketplaces.
"""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Set

from lux.nft.connectors.aggregator import MultiMarketplaceAggregator
from lux.nft.sales.dedup import EventDeduplicator, ReplayBuffer
from lux.nft.sales.normalizer import SalesEventNormalizer
from lux.nft.types import Marketplace, SaleEvent

logger = logging.getLogger(__name__)


@dataclass
class EventFilterConfig:
    min_price_eth: Optional[float] = None
    max_price_eth: Optional[float] = None
    whale_threshold_eth: float = 10.0  # Alert threshold for large purchases
    token_ids: Optional[Set[str]] = None
    marketplaces: Optional[Set[Marketplace]] = None


class SalesStreamPoller:
    """
    Continuous & On-Demand Sales Monitoring Stream.
    Coordinates polling across OpenSea, Blur, and LooksRare with deduplication,
    real-time event normalization, filtering, and callback dispatching.
    """

    def __init__(
        self,
        aggregator: Optional[MultiMarketplaceAggregator] = None,
        filter_config: Optional[EventFilterConfig] = None,
        normalizer: Optional[SalesEventNormalizer] = None,
        deduplicator: Optional[EventDeduplicator] = None,
        replay_buffer: Optional[ReplayBuffer] = None,
        poll_interval_seconds: float = 5.0,
    ):
        self.aggregator = aggregator or MultiMarketplaceAggregator()
        self.filter_config = filter_config or EventFilterConfig()
        self.normalizer = normalizer or SalesEventNormalizer()
        self.deduplicator = deduplicator or EventDeduplicator()
        self.replay_buffer = replay_buffer or ReplayBuffer()
        self.poll_interval = poll_interval_seconds

        self._subscribers: List[Callable[[SaleEvent], None]] = []
        self._whale_subscribers: List[Callable[[SaleEvent], None]] = []
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._lock = threading.RLock()
        self._watched_collections: Set[str] = set()

    def add_subscriber(self, callback: Callable[[SaleEvent], None]) -> None:
        with self._lock:
            self._subscribers.append(callback)

    def add_whale_subscriber(self, callback: Callable[[SaleEvent], None]) -> None:
        with self._lock:
            self._whale_subscribers.append(callback)

    def watch_collection(self, collection_address: str) -> None:
        with self._lock:
            self._watched_collections.add(collection_address.lower())

    def unwatch_collection(self, collection_address: str) -> None:
        with self._lock:
            self._watched_collections.discard(collection_address.lower())

    def is_match_filter(self, event: SaleEvent) -> bool:
        """Evaluates whether an event satisfies configured filters."""
        fc = self.filter_config
        if fc.min_price_eth is not None and event.price_eth < fc.min_price_eth:
            return False
        if fc.max_price_eth is not None and event.price_eth > fc.max_price_eth:
            return False
        if fc.token_ids is not None and event.token_id not in fc.token_ids:
            return False
        if fc.marketplaces is not None and event.marketplace not in fc.marketplaces:
            return False
        return True

    def process_raw_events(self, raw_events: List[Dict[str, Any]], marketplace: Optional[Marketplace] = None) -> List[SaleEvent]:
        """Normalizes and deduplicates a batch of incoming raw events."""
        normalized: List[SaleEvent] = []
        for raw in raw_events:
            try:
                sale = self.normalizer.normalize(raw, marketplace=marketplace)
                if self.deduplicator.check_and_add(sale):
                    self.replay_buffer.append(sale)
                    if self.is_match_filter(sale):
                        normalized.append(sale)
                        self._dispatch(sale)
            except Exception as e:
                logger.error(f"Error normalizing sales event: {e}")
        return normalized

    def poll_once(self, collection_address: str, limit_per_venue: int = 30) -> List[SaleEvent]:
        """
        Executes a single polling pass across all marketplaces for a collection,
        deduplicating and filtering events.
        """
        all_new_sales: List[SaleEvent] = []

        for mkt, conn in self.aggregator.connectors.items():
            try:
                sales = conn.get_recent_sales(collection_address, limit=limit_per_venue)
                for sale in sales:
                    if self.deduplicator.check_and_add(sale):
                        self.replay_buffer.append(sale)
                        if self.is_match_filter(sale):
                            all_new_sales.append(sale)
                            self._dispatch(sale)
            except Exception as e:
                logger.warning(f"Error polling sales on {mkt.value} for {collection_address}: {e}")

        all_new_sales.sort(key=lambda s: s.timestamp, reverse=True)
        return all_new_sales

    def _dispatch(self, event: SaleEvent) -> None:
        """Notifies registered listeners of new sale and whale events."""
        with self._lock:
            subs = list(self._subscribers)
            whale_subs = list(self._whale_subscribers)

        for callback in subs:
            try:
                callback(event)
            except Exception as e:
                logger.error(f"Error in sale subscriber callback: {e}")

        if event.price_eth >= self.filter_config.whale_threshold_eth:
            for w_cb in whale_subs:
                try:
                    w_cb(event)
                except Exception as e:
                    logger.error(f"Error in whale subscriber callback: {e}")

    def start_polling(self) -> None:
        """Starts background daemon poller thread."""
        with self._lock:
            if self._running:
                return
            self._running = True
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()
            logger.info("SalesStreamPoller background thread started.")

    def stop_polling(self) -> None:
        """Stops background poller thread gracefully."""
        with self._lock:
            self._running = False
        if self._thread:
            self._thread.join(timeout=2.0)
            self._thread = None
            logger.info("SalesStreamPoller stopped.")

    def _run_loop(self) -> None:
        while self._running:
            with self._lock:
                collections = list(self._watched_collections)

            for col in collections:
                if not self._running:
                    break
                try:
                    self.poll_once(col)
                except Exception as e:
                    logger.error(f"Exception during polling loop for {col}: {e}")

            time.sleep(self.poll_interval)
