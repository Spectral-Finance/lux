"""
High-Level NFT Marketplace Data Aggregation Pipeline for Lux.
Seamlessly unifies Multi-Marketplace Connectors, Price Tracking, Sales Monitoring, and Rarity Engines.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional
import time

from lux.nft.connectors.aggregator import MultiMarketplaceAggregator
from lux.nft.pricing.engine import PriceTrackingEngine
from lux.nft.rarity.engine import TraitRarityEngine
from lux.nft.sales.dedup import EventDeduplicator, ReplayBuffer
from lux.nft.sales.normalizer import SalesEventNormalizer
from lux.nft.sales.poller import EventFilterConfig, SalesStreamPoller
from lux.nft.types import (
    AggregatedFloorPrice,
    CollectionRarityReport,
    CollectionStats,
    PriceTrendAnalysis,
    SaleEvent,
    TokenMetadata,
)

logger = logging.getLogger(__name__)


class NFTMarketplacePipeline:
    """
    Unified Production-Grade Pipeline for NFT Data Aggregation & Analysis.
    """

    def __init__(
        self,
        aggregator: Optional[MultiMarketplaceAggregator] = None,
        pricing_engine: Optional[PriceTrackingEngine] = None,
        rarity_engine: Optional[TraitRarityEngine] = None,
        sales_poller: Optional[SalesStreamPoller] = None,
    ):
        self.aggregator = aggregator or MultiMarketplaceAggregator()
        self.pricing_engine = pricing_engine or PriceTrackingEngine()
        self.rarity_engine = rarity_engine or TraitRarityEngine()
        self.sales_poller = sales_poller or SalesStreamPoller(aggregator=self.aggregator)

    def analyze_collection_full(
        self,
        collection_address: str,
        tokens_metadata: Optional[List[TokenMetadata]] = None,
        total_supply: Optional[int] = None,
        historical_sales: Optional[List[SaleEvent]] = None,
        floor_history_hourly: Optional[List[float]] = None,
    ) -> Dict[str, Any]:
        """
        Executes a complete end-to-end multi-marketplace aggregation, price tracking,
        sales normalization, and rarity analysis pipeline.
        """
        addr = collection_address.lower()

        # 1. Fetch cross-marketplace floor prices
        aggregated_floor: AggregatedFloorPrice = self.aggregator.get_aggregated_floor_price(addr)

        # 2. Fetch cross-marketplace volume & collection stats
        collection_stats: CollectionStats = self.aggregator.get_aggregated_stats(addr)

        # 3. Fetch or use provided sales feed
        if historical_sales is None:
            sales_feed = self.sales_poller.poll_once(addr, limit_per_venue=50)
        else:
            sales_feed = historical_sales

        # 4. Perform price tracking & trend analysis
        current_floor = (
            aggregated_floor.best_floor_price_eth
            if aggregated_floor.best_floor_price_eth > 0
            else collection_stats.floor_price_eth
        )
        trend_analysis: PriceTrendAnalysis = self.pricing_engine.analyze_price_trends(
            collection_address=addr,
            current_floor_eth=current_floor,
            historical_sales=sales_feed,
            floor_history_hourly=floor_history_hourly,
        )

        # 5. Calculate trait rarity if metadata is supplied
        rarity_report: Optional[CollectionRarityReport] = None
        if tokens_metadata:
            rarity_report = self.rarity_engine.analyze_collection(
                collection_address=addr,
                tokens=tokens_metadata,
                total_supply=total_supply or collection_stats.total_supply,
            )

        return {
            "collection_address": addr,
            "timestamp": time.time(),
            "floor_pricing": aggregated_floor.to_dict(),
            "collection_stats": collection_stats.to_dict(),
            "trend_analysis": trend_analysis.to_dict(),
            "recent_sales": [s.to_dict() for s in sales_feed[:25]],
            "rarity_summary": (
                {
                    "total_supply": rarity_report.total_supply,
                    "total_traits_count": rarity_report.total_traits_count,
                    "top_rarest_tokens": [ts.to_dict() for ts in rarity_report.token_scores[:5]],
                    "trait_entropy": rarity_report.trait_entropy,
                }
                if rarity_report
                else None
            ),
        }
