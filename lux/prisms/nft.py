"""NFT aggregation and analysis prisms."""
import asyncio
import logging
from typing import Any, Dict, List

from lux.lenses.opensea.collections import get_collection as get_opensea_collection
from lux.lenses.blur.collections import get_collection as get_blur_collection
from lux.utils.http import create_session

logger = logging.getLogger(__name__)


async def get_floor_price_across_marketplaces(
    collection_slug: str,
) -> Dict[str, Any]:
    """
    Get floor price for a collection across multiple marketplaces.

    Returns the lowest floor price and source marketplace.
    """
    async with create_session() as session:
        tasks = [
            get_opensea_collection(session, collection_slug),
            get_blur_collection(session, collection_slug),
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        floor_prices = []
        sources = {}

        for result in results:
            if isinstance(result, Exception):
                logger.error(f"Error fetching collection data: {result}")
                continue
            if not result:
                continue

            if result.get("floor_price") is not None:
                marketplace = result.get("marketplace", "opensea")
                price = float(result["floor_price"])
                floor_prices.append(price)
                sources[marketplace] = price

        if not floor_prices:
            return {"floor_price": None, "source": None, "all_prices": {}}

        lowest_price = min(floor_prices)
        source = next(
            (mp for mp, price in sources.items() if price == lowest_price),
            "unknown",
        )

        return {
            "floor_price": lowest_price,
            "source": source,
            "all_prices": sources,
        }


async def analyze_rarity(
    collection_slug: str,
    token_id: str,
) -> Dict[str, Any]:
    """
    Analyze rarity of an NFT based on trait frequency.

    Uses OpenSea data for trait distribution.
    """
    # This is a simplified rarity scoring based on trait frequency
    # In practice, would fetch full collection traits and calculate rarity scores
    async with create_session() as session:
        collection_data = await get_opensea_collection(session, collection_slug)
        if not collection_data:
            return {"rarity_score": None, "rank": None, "trait_count": None}

        # Would normally fetch all NFTs and calculate trait frequencies
        # For now, return placeholder with note
        return {
            "rarity_score": 0.0,
            "rank": 0,
            "trait_count": 0,
            "note": "Full rarity engine requires trait frequency analysis across entire collection",
        }


async def get_market_trends(
    collection_slug: str,
) -> Dict[str, Any]:
    """
    Get market trends for a collection (24h/7d volume changes).

    Aggregates data from multiple marketplaces.
    """
    async with create_session() as session:
        opensea_data = await get_opensea_collection(session, collection_slug)
        blur_data = await get_blur_collection(session, collection_slug)

        trends = {
            "collection_slug": collection_slug,
            "volume_24h": 0.0,
            "volume_7d": 0.0,
            "floor_price_change_24h": 0.0,
            "sources": {},
        }

        if opensea_data:
            trends["sources"]["opensea"] = {
                "volume_24h": opensea_data.get("one_day_volume", 0.0),
                "volume_7d": opensea_data.get("seven_day_volume", 0.0),
            }
            trends["volume_24h"] += opensea_data.get("one_day_volume", 0.0)
            trends["volume_7d"] += opensea_data.get("seven_day_volume", 0.0)

        if blur_data:
            # Blur doesn't expose 24h volume directly in this endpoint
            trends["sources"]["blur"] = {
                "volume_24h": 0.0,
                "volume_7d": 0.0,
            }

        return trends