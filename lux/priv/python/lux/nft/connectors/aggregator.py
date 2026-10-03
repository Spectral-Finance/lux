"""
Multi-Marketplace Aggregator for OpenSea, Blur, LooksRare.
Combines data across multiple NFT venues with concurrent execution and fallback.
"""

from __future__ import annotations

import concurrent.futures
import logging
from typing import Any, Dict, List, Optional
import time

from lux.nft.connectors.base import BaseMarketplaceConnector
from lux.nft.connectors.blur import BlurConnector
from lux.nft.connectors.looksrare import LooksRareConnector
from lux.nft.connectors.opensea import OpenSeaConnector
from lux.nft.types import (
    AggregatedFloorPrice,
    CollectionStats,
    FloorPriceQuote,
    Marketplace,
    SaleEvent,
    ValidationError,
)

logger = logging.getLogger(__name__)


class MultiMarketplaceAggregator:
    """
    Coordinates and aggregates data across OpenSea, Blur, and LooksRare.
    Features:
    - Parallel querying across venues
    - Graceful error containment (partial results returned if a venue fails)
    - Unified floor price comparison and spread analysis
    - Unified sales feed merger
    """

    def __init__(
        self,
        opensea_connector: Optional[OpenSeaConnector] = None,
        blur_connector: Optional[BlurConnector] = None,
        looksrare_connector: Optional[LooksRareConnector] = None,
        max_workers: int = 4,
    ):
        self.connectors: Dict[Marketplace, BaseMarketplaceConnector] = {}

        if opensea_connector:
            self.connectors[Marketplace.OPENSEA] = opensea_connector
        else:
            self.connectors[Marketplace.OPENSEA] = OpenSeaConnector()

        if blur_connector:
            self.connectors[Marketplace.BLUR] = blur_connector
        else:
            self.connectors[Marketplace.BLUR] = BlurConnector()

        if looksrare_connector:
            self.connectors[Marketplace.LOOKSRARE] = looksrare_connector
        else:
            self.connectors[Marketplace.LOOKSRARE] = LooksRareConnector()

        self.max_workers = max_workers

    def register_connector(self, marketplace: Marketplace, connector: BaseMarketplaceConnector) -> None:
        self.connectors[marketplace] = connector

    def get_connector(self, marketplace: Marketplace) -> Optional[BaseMarketplaceConnector]:
        return self.connectors.get(marketplace)

    def get_aggregated_floor_price(self, collection_address: str) -> AggregatedFloorPrice:
        """
        Queries all marketplaces in parallel to calculate the lowest floor price,
        best marketplace, and cross-venue price spread.
        """
        if not collection_address:
            raise ValidationError("collection_address is required")

        quotes: Dict[str, FloorPriceQuote] = {}
        valid_quotes: List[FloorPriceQuote] = []

        def _fetch_floor(mkt: Marketplace, conn: BaseMarketplaceConnector) -> Optional[FloorPriceQuote]:
            try:
                quote = conn.get_floor_price(collection_address)
                if quote.floor_price_eth > 0:
                    return quote
            except Exception as e:
                logger.warning(f"Failed to fetch floor price from {mkt.value}: {e}")
            return None

        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_mkt = {
                executor.submit(_fetch_floor, mkt, conn): mkt for mkt, conn in self.connectors.items()
            }
            for future in concurrent.futures.as_completed(future_to_mkt):
                res = future.result()
                if res:
                    quotes[res.marketplace.value] = res
                    valid_quotes.append(res)

        if not valid_quotes:
            # Return zero aggregated quote if all failed
            return AggregatedFloorPrice(
                collection_address=collection_address.lower(),
                best_floor_price_eth=0.0,
                best_floor_price_usd=0.0,
                best_marketplace=Marketplace.UNKNOWN,
                quotes={},
                spread_eth=0.0,
                spread_percent=0.0,
            )

        # Sort by lowest floor price
        valid_quotes.sort(key=lambda q: q.floor_price_eth)
        best_quote = valid_quotes[0]
        highest_quote = valid_quotes[-1]

        spread_eth = highest_quote.floor_price_eth - best_quote.floor_price_eth
        spread_percent = (
            (spread_eth / best_quote.floor_price_eth) * 100.0 if best_quote.floor_price_eth > 0 else 0.0
        )

        return AggregatedFloorPrice(
            collection_address=collection_address.lower(),
            best_floor_price_eth=best_quote.floor_price_eth,
            best_floor_price_usd=best_quote.floor_price_usd,
            best_marketplace=best_quote.marketplace,
            quotes=quotes,
            spread_eth=spread_eth,
            spread_percent=spread_percent,
            timestamp=time.time(),
        )

    def get_aggregated_stats(self, collection_address: str) -> CollectionStats:
        """
        Queries all marketplaces and aggregates volume, sales counts, and market cap.
        """
        all_stats: List[CollectionStats] = []

        def _fetch_stats(mkt: Marketplace, conn: BaseMarketplaceConnector) -> Optional[CollectionStats]:
            try:
                return conn.get_collection_stats(collection_address)
            except Exception as e:
                logger.warning(f"Failed to fetch collection stats from {mkt.value}: {e}")
            return None

        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [executor.submit(_fetch_stats, mkt, conn) for mkt, conn in self.connectors.items()]
            for f in concurrent.futures.as_completed(futures):
                s = f.result()
                if s:
                    all_stats.append(s)

        if not all_stats:
            return CollectionStats(
                collection_address=collection_address.lower(),
                name=collection_address,
            )

        # Aggregate metrics
        best_floor = min((s.floor_price_eth for s in all_stats if s.floor_price_eth > 0), default=0.0)
        best_floor_usd = min((s.floor_price_usd for s in all_stats if s.floor_price_usd > 0), default=0.0)
        total_supply = max((s.total_supply for s in all_stats), default=0)
        num_owners = max((s.num_owners for s in all_stats), default=0)

        vol_1h = sum(s.volume_1h_eth for s in all_stats)
        vol_24h = sum(s.volume_24h_eth for s in all_stats)
        vol_7d = sum(s.volume_7d_eth for s in all_stats)
        vol_30d = sum(s.volume_30d_eth for s in all_stats)
        vol_total = sum(s.volume_total_eth for s in all_stats)

        sales_1h = sum(s.sales_1h for s in all_stats)
        sales_24h = sum(s.sales_24h for s in all_stats)
        sales_7d = sum(s.sales_7d for s in all_stats)
        sales_30d = sum(s.sales_30d for s in all_stats)
        sales_total = sum(s.sales_total for s in all_stats)

        avg_price_24h = (vol_24h / max(1, sales_24h)) if sales_24h > 0 else 0.0

        return CollectionStats(
            collection_address=collection_address.lower(),
            name=all_stats[0].name,
            symbol=all_stats[0].symbol,
            total_supply=total_supply,
            num_owners=num_owners,
            floor_price_eth=best_floor,
            floor_price_usd=best_floor_usd,
            volume_1h_eth=vol_1h,
            volume_24h_eth=vol_24h,
            volume_7d_eth=vol_7d,
            volume_30d_eth=vol_30d,
            volume_total_eth=vol_total,
            sales_1h=sales_1h,
            sales_24h=sales_24h,
            sales_7d=sales_7d,
            sales_30d=sales_30d,
            sales_total=sales_total,
            average_price_24h_eth=avg_price_24h,
            market_cap_eth=best_floor * total_supply,
            timestamp=time.time(),
        )

    def get_aggregated_recent_sales(
        self, collection_address: str, limit: int = 50
    ) -> List[SaleEvent]:
        """
        Fetches recent sales from OpenSea, Blur, and LooksRare, merges and sorts by timestamp descending.
        """
        all_sales: List[SaleEvent] = []

        def _fetch_sales(mkt: Marketplace, conn: BaseMarketplaceConnector) -> List[SaleEvent]:
            try:
                return conn.get_recent_sales(collection_address, limit=limit)
            except Exception as e:
                logger.warning(f"Failed to fetch sales from {mkt.value}: {e}")
                return []

        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [executor.submit(_fetch_sales, mkt, conn) for mkt, conn in self.connectors.items()]
            for f in concurrent.futures.as_completed(futures):
                all_sales.extend(f.result())

        # Sort by timestamp descending
        all_sales.sort(key=lambda s: s.timestamp, reverse=True)
        return all_sales[:limit]

    def health_check_all(self) -> Dict[str, Any]:
        """Checks the health and circuit state of all registered connectors."""
        results = {}
        for mkt, conn in self.connectors.items():
            results[mkt.value] = conn.health_check()
        return results
