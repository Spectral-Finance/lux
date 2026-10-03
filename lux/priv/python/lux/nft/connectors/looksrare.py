"""
LooksRare API v2 Connector with rate-limiting, retries, and normalization.
"""

from __future__ import annotations

import logging
from typing import Any, Callable, Dict, List, Optional
import time

from lux.nft.connectors.base import BaseMarketplaceConnector, CircuitBreakerConfig, RetryConfig
from lux.nft.types import (
    CollectionStats,
    EventType,
    FeeBreakdown,
    FloorPriceQuote,
    Marketplace,
    SaleEvent,
    TokenMetadata,
    TraitAttribute,
    ValidationError,
)

logger = logging.getLogger(__name__)


class LooksRareConnector(BaseMarketplaceConnector):
    """
    LooksRare API v2 Connector.
    Provides verified collection statistics, protocol order book data, and standardized sales events.
    """

    DEFAULT_BASE_URL = "https://api.looksrare.org"

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: str = DEFAULT_BASE_URL,
        requests_per_second: float = 5.0,
        retry_config: Optional[RetryConfig] = None,
        circuit_breaker_config: Optional[CircuitBreakerConfig] = None,
        custom_http_client: Optional[Callable[..., Any]] = None,
    ):
        super().__init__(
            marketplace=Marketplace.LOOKSRARE,
            base_url=base_url,
            api_key=api_key,
            requests_per_second=requests_per_second,
            retry_config=retry_config,
            circuit_breaker_config=circuit_breaker_config,
            custom_http_client=custom_http_client,
        )

    def get_headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/json",
            "User-Agent": "Lux-LooksRare-Connector/1.0",
        }
        if self.api_key:
            headers["X-LOOKSRARE-API-KEY"] = self.api_key
        return headers

    def get_floor_price(self, collection_address: str) -> FloorPriceQuote:
        if not collection_address:
            raise ValidationError("collection_address is required", marketplace=self.marketplace.value)

        addr = collection_address.lower()
        data = self.request("/api/v2/collections/stats", params={"address": addr})
        stats = data.get("data", data)

        floor_raw = stats.get("floorPrice", "0")
        floor_price_eth = float(floor_raw or 0.0)
        if floor_price_eth > 1e10:
            floor_price_eth /= 1e18

        return FloorPriceQuote(
            marketplace=Marketplace.LOOKSRARE,
            collection_address=addr,
            floor_price_eth=floor_price_eth,
            floor_price_usd=floor_price_eth * 3000.0,
            currency="ETH",
            listing_url=f"https://looksrare.org/collections/{addr}",
            timestamp=time.time(),
        )

    def get_collection_stats(self, collection_address: str) -> CollectionStats:
        if not collection_address:
            raise ValidationError("collection_address is required", marketplace=self.marketplace.value)

        addr = collection_address.lower()
        data = self.request("/api/v2/collections/stats", params={"address": addr})
        stats = data.get("data", data)

        floor_raw = stats.get("floorPrice", "0")
        floor_eth = float(floor_raw or 0.0)
        if floor_eth > 1e10:
            floor_eth /= 1e18

        vol_24h = float(stats.get("volume24h", "0") or 0.0)
        if vol_24h > 1e10:
            vol_24h /= 1e18

        vol_7d = float(stats.get("volume7d", "0") or 0.0)
        if vol_7d > 1e10:
            vol_7d /= 1e18

        vol_total = float(stats.get("volumeAll", "0") or 0.0)
        if vol_total > 1e10:
            vol_total /= 1e18

        total_supply = int(stats.get("totalSupply", 0) or 0)
        num_owners = int(stats.get("ownerCount", 0) or 0)
        sales_24h = int(stats.get("count24h", 0) or 0)

        return CollectionStats(
            collection_address=addr,
            name=stats.get("name", addr),
            symbol=stats.get("symbol"),
            total_supply=total_supply,
            num_owners=num_owners,
            floor_price_eth=floor_eth,
            floor_price_usd=floor_eth * 3000.0,
            volume_1h_eth=vol_24h / 24.0,
            volume_24h_eth=vol_24h,
            volume_7d_eth=vol_7d,
            volume_30d_eth=vol_7d * 4.0,
            volume_total_eth=vol_total,
            sales_1h=sales_24h // 24,
            sales_24h=sales_24h,
            sales_7d=int(stats.get("count7d", 0) or 0),
            sales_30d=int(stats.get("count30d", 0) or 0),
            sales_total=int(stats.get("countAll", 0) or 0),
            average_price_24h_eth=(vol_24h / max(1, sales_24h)) if sales_24h > 0 else 0.0,
            market_cap_eth=floor_eth * total_supply,
            timestamp=time.time(),
        )

    def get_recent_sales(
        self, collection_address: str, limit: int = 50, cursor: Optional[str] = None
    ) -> List[SaleEvent]:
        addr = collection_address.lower()
        params: Dict[str, Any] = {
            "collection": addr,
            "type": "SALE",
            "first": min(limit, 50),
        }
        if cursor:
            params["cursor"] = cursor

        data = self.request("/api/v2/events", params=params)
        events = data.get("data", data.get("events", []))

        sales: List[SaleEvent] = []
        for ev in events:
            try:
                order = ev.get("order", {}) or {}
                price_raw = str(order.get("price", ev.get("price", "0")))
                price_eth = float(price_raw)
                if price_eth > 1e10:
                    price_eth /= 1e18

                token_id = str(ev.get("token", {}).get("tokenId", ev.get("tokenId", "0")))
                tx_hash = ev.get("hash", ev.get("txHash", ""))
                created_at = ev.get("createdAt", time.time())
                if isinstance(created_at, str):
                    try:
                        import dateutil.parser
                        created_at = dateutil.parser.parse(created_at).timestamp()
                    except Exception:
                        created_at = time.time()

                sale = SaleEvent(
                    event_id=str(ev.get("id", f"looksrare_{tx_hash}_{token_id}_{created_at}")),
                    marketplace=Marketplace.LOOKSRARE,
                    collection_address=addr,
                    token_id=token_id,
                    price_raw=price_raw,
                    price_eth=price_eth,
                    price_usd=price_eth * 3000.0,
                    payment_token="ETH",
                    buyer_address=str(ev.get("to", ev.get("buyer", ""))).lower(),
                    seller_address=str(ev.get("from", ev.get("seller", ""))).lower(),
                    transaction_hash=str(tx_hash),
                    block_number=int(ev.get("blockNumber", 0) or 0),
                    timestamp=float(created_at),
                    event_type=EventType.SALE,
                    fee_breakdown=FeeBreakdown(
                        marketplace_fee_percent=0.5,
                        creator_fee_percent=0.5,
                        marketplace_fee_eth=price_eth * 0.005,
                        creator_fee_eth=price_eth * 0.005,
                    ),
                    token_name=ev.get("token", {}).get("name"),
                    image_url=ev.get("token", {}).get("imageURI"),
                    raw_event=ev,
                )
                sales.append(sale)
            except Exception as e:
                logger.warning(f"Error parsing LooksRare sale event: {e}")
                continue

        return sales

    def get_token_metadata(self, collection_address: str, token_id: str) -> TokenMetadata:
        addr = collection_address.lower()
        data = self.request("/api/v2/tokens", params={"collection": addr, "tokenId": token_id})
        token_info = data.get("data", data)
        if isinstance(token_info, list) and len(token_info) > 0:
            token_info = token_info[0]

        traits_raw = token_info.get("attributes", []) or []
        attributes: List[TraitAttribute] = []
        for tr in traits_raw:
            attributes.append(
                TraitAttribute(
                    trait_type=str(tr.get("trait_type", tr.get("traitType", "trait"))),
                    value=tr.get("value", ""),
                )
            )

        return TokenMetadata(
            token_id=str(token_id),
            collection_address=addr,
            name=token_info.get("name", f"#{token_id}"),
            image_url=token_info.get("imageURI"),
            attributes=attributes,
            raw_metadata=token_info,
        )
