"""OpenSea collection data lenses."""
import asyncio
import logging
from typing import Any, Dict, Optional
from urllib.parse import urlencode

import aiohttp

from lux.config import settings
from lux.utils.http import with_retry

logger = logging.getLogger(__name__)


@with_retry(max_retries=3, backoff_base=1.5)
async def get_collection(
    session: aiohttp.ClientSession, collection_slug: str
) -> Dict[str, Any]:
    """
    Fetch collection data from OpenSea.

    Returns comprehensive collection stats including floor price, volume, and ownership.

    API: https://docs.opensea.io/reference/retrieving-a-single-collection
    """
    url = f"{settings.opensea_api_base}/collections/{collection_slug}"
    headers = {
        "Accept": "application/json",
        "User-Agent": settings.user_agent,
    }
    if settings.opensea_api_key:
        headers["X-API-KEY"] = settings.opensea_api_key

    try:
        async with session.get(url, headers=headers) as response:
            if response.status == 404:
                logger.warning(f"Collection not found: {collection_slug}")
                return {}
            elif response.status == 429:
                logger.warning(f"Rate limited fetching collection {collection_slug}")
                raise aiohttp.ClientResponseError(
                    response.request_info,
                    response.history,
                    status=response.status,
                    message="Rate limited by OpenSea API",
                )
            elif response.status >= 400:
                logger.error(
                    f"Error fetching collection {collection_slug}: {response.status} {await response.text()}"
                )
                return {}

            data = await response.json()
            return _normalize_collection_data(data)

    except aiohttp.ClientError as e:
        logger.error(f"HTTP error fetching collection {collection_slug}: {e}")
        raise


def _normalize_collection_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize OpenSea collection data into standard format."""
    if not data:
        return {}

    stats = data.get("stats", {}) or {}
    primary_asset_contracts = data.get("primary_asset_contracts", [])

    # Extract contract address from primary_asset_contracts if available
    contract_address = None
    if primary_asset_contracts:
        contract = primary_asset_contracts[0]
        contract_address = contract.get("address")

    return {
        "collection": data.get("collection"),
        "name": data.get("name"),
        "slug": data.get("slug"),
        "description": data.get("description"),
        "image_url": data.get("image_url"),
        "external_url": data.get("external_url"),
        "twitter_username": data.get("twitter_username"),
        "discord_url": data.get("discord_url"),
        "contract_address": contract_address,
        "chain": "ethereum",  # OpenSea v2 defaults to ethereum
        "num_owners": stats.get("num_owners", 0),
        "num_assets": stats.get("total_supply") or stats.get("count", 0),
        "floor_price": stats.get("floor_price"),
        "total_volume": stats.get("total_volume"),
        "seven_day_volume": stats.get("seven_day_volume"),
        "thirty_day_volume": stats.get("thirty_day_volume"),
        "market_cap": stats.get("market_cap"),
    }


@with_retry(max_retries=3, backoff_base=1.5)
async def list_nfts(
    session: aiohttp.ClientSession,
    collection_slug: str,
    limit: int = 20,
    cursor: Optional[str] = None,
) -> Dict[str, Any]:
    """
    List NFTs in a collection with pagination support.

    Returns paginated list of NFTs with traits and metadata.

    API: https://docs.opensea.io/reference/getting-nfts
    """
    params = {
        "collection": collection_slug,
        "limit": limit,
    }
    if cursor:
        params["cursor"] = cursor

    url = f"{settings.opensea_api_base}/assets?{urlencode(params)}"
    headers = {
        "Accept": "application/json",
        "User-Agent": settings.user_agent,
    }
    if settings.opensea_api_key:
        headers["X-API-KEY"] = settings.opensea_api_key

    try:
        async with session.get(url, headers=headers) as response:
            if response.status == 429:
                logger.warning(f"Rate limited fetching NFTs for {collection_slug}")
                raise aiohttp.ClientResponseError(
                    response.request_info,
                    response.history,
                    status=response.status,
                    message="Rate limited by OpenSea API",
                )
            elif response.status >= 400:
                logger.error(
                    f"Error fetching NFTs for {collection_slug}: {response.status} {await response.text()}"
                )
                return {"nfts": [], "next": None}

            data = await response.json()
            return {
                "nfts": [_normalize_nft(nft) for nft in data.get("assets", [])],
                "next": data.get("next"),
            }

    except aiohttp.ClientError as e:
        logger.error(f"HTTP error fetching NFTs for {collection_slug}: {e}")
        raise


def _normalize_nft(data: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize OpenSea NFT data into standard format."""
    return {
        "token_id": data.get("token_id"),
        "contract_address": data.get("asset_contract", {}).get("address"),
        "collection_slug": data.get("collection", {}).get("slug"),
        "name": data.get("name"),
        "description": data.get("description"),
        "image_url": data.get("image_url"),
        "external_link": data.get("external_link"),
        "owner": data.get("owner", {}).get("address"),
        "traits": [
            {
                "trait_type": trait.get("trait_type"),
                "value": trait.get("value"),
                "count": trait.get("trait_count"),
            }
            for trait in data.get("traits", [])
        ],
        "last_sale": _normalize_sale(data.get("last_sale")),
        "top_bid": data.get("top_bid"),
        "listing_date": data.get("listing_date"),
        "permalink": data.get("permalink"),
    }


def _normalize_sale(data: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Normalize OpenSea sale event data."""
    if not data:
        return None

    payment_token = data.get("payment_token", {}) or {}
    return {
        "event_type": data.get("event_type"),
        "total_price": data.get("total_price"),
        "payment_token": {
            "symbol": payment_token.get("symbol"),
            "decimals": payment_token.get("decimals"),
            "address": payment_token.get("address"),
            "eth_price": payment_token.get("eth_price"),
        },
        "quantity": data.get("quantity"),
        "created_date": data.get("created_date"),
    }


@with_retry(max_retries=3, backoff_base=1.5)
async def get_collection_events(
    session: aiohttp.ClientSession,
    collection_slug: str,
    event_type: str = "successful",  # successful = sale
    limit: int = 20,
    cursor: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Fetch collection events (sales, transfers) from OpenSea.

    API: https://docs.opensea.io/reference/retrieving-asset-events
    """
    params = {
        "collection_slug": collection_slug,
        "event_type": event_type,
        "limit": limit,
    }
    if cursor:
        params["cursor"] = cursor

    url = f"{settings.opensea_api_base}/events?{urlencode(params)}"
    headers = {
        "Accept": "application/json",
        "User-Agent": settings.user_agent,
    }
    if settings.opensea_api_key:
        headers["X-API-KEY"] = settings.opensea_api_key

    try:
        async with session.get(url, headers=headers) as response:
            if response.status == 429:
                logger.warning(
                    f"Rate limited fetching events for {collection_slug}"
                )
                raise aiohttp.ClientResponseError(
                    response.request_info,
                    response.history,
                    status=response.status,
                    message="Rate limited by OpenSea API",
                )
            elif response.status >= 400:
                logger.error(
                    f"Error fetching events for {collection_slug}: {response.status} {await response.text()}"
                )
                return {"events": [], "next": None}

            data = await response.json()
            return {
                "events": [_normalize_event(event) for event in data.get("asset_events", [])],
                "next": data.get("next"),
            }

    except aiohttp.ClientError as e:
        logger.error(f"HTTP error fetching events for {collection_slug}: {e}")
        raise


def _normalize_event(data: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize OpenSea event data."""
    payment_token = data.get("payment_token", {}) or {}
    return {
        "event_type": data.get("event_type"),
        "event_timestamp": data.get("event_timestamp"),
        "happened_at": data.get("happened_at"),
        "asset": {
            "token_id": data.get("asset", {}).get("token_id"),
            "contract_address": data.get("asset", {}).get("asset_contract", {}).get("address"),
            "collection_slug": data.get("asset", {}).get("collection", {}).get("slug"),
        },
        "total_price": data.get("total_price"),
        "payment_token": {
            "symbol": payment_token.get("symbol"),
            "decimals": payment_token.get("decimals"),
            "address": payment_token.get("address"),
            "eth_price": payment_token.get("eth_price"),
        },
        "quantity": data.get("quantity"),
        "seller": data.get("seller", {}).get("address"),
        "winner_account": data.get("winner_account", {}).get("address"),
        "transaction": {
            "transaction_hash": data.get("transaction", {}).get("transaction_hash"),
            "block_number": data.get("transaction", {}).get("block_number"),
        },
    }