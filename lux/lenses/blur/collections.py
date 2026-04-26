"""Blur marketplace collection lenses."""
import asyncio
import logging
from typing import Any, Dict

import aiohttp

from lux.config import settings
from lux.utils.http import with_retry

logger = logging.getLogger(__name__)


@with_retry(max_retries=3, backoff_base=1.5)
async def get_collection(
    session: aiohttp.ClientSession, collection_slug: str
) -> Dict[str, Any]:
    """
    Fetch collection data from Blur.

    Returns floor price and volume stats.

    Note: Blur API is undocumented; using public endpoints observed in browser.
    """
    # Using Blur's GraphQL-like endpoint for collection stats
    url = "https://api.blur.io/v1/collections"
    headers = {
        "Accept": "application/json",
        "User-Agent": settings.user_agent,
        "Referer": "https://blur.io/",
    }

    payload = {
        "collectionQuery": {"slug": collection_slug},
        "sort": {"sortType": "SALE_COUNT", "direction": "DESC"},
        "range": {"size": 1, "from": 0},
        "contractAddresses": [],
        "searchType": "COLLECTIONS",
    }

    try:
        async with session.post(url, headers=headers, json=payload) as response:
            if response.status == 404:
                logger.warning(f"Blur collection not found: {collection_slug}")
                return {}
            elif response.status == 429:
                logger.warning(f"Rate limited by Blur API for {collection_slug}")
                raise aiohttp.ClientResponseError(
                    response.request_info,
                    response.history,
                    status=response.status,
                    message="Rate limited by Blur API",
                )
            elif response.status >= 400:
                logger.error(
                    f"Error fetching Blur collection {collection_slug}: {response.status} {await response.text()}"
                )
                return {}

            data = await response.json()
            collections = data.get("collections", [])
            if not collections:
                return {}

            collection = collections[0]
            stats = collection.get("stats", {}) or {}

            return {
                "collection": collection.get("collection"),
                "name": collection.get("name"),
                "slug": collection.get("slug"),
                "floor_price": stats.get("floorPrice"),
                "total_volume": stats.get("totalVolume"),
                "thirty_day_volume": stats.get("volume30d"),
                "marketplace": "blur",
            }

    except aiohttp.ClientError as e:
        logger.error(f"HTTP error fetching Blur collection {collection_slug}: {e}")
        raise