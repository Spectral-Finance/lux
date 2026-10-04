"""
Blur Marketplace API & Feed Connector with rate-limiting, retries, and normalization.
"""

from __future__ import annotations

import json
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


class BlurConnector(BaseMarketplaceConnector):
    """
    Blur Marketplace Connector.
    Provides low-latency floor prices, blend loan stats, and high-frequency sales events.
    """

    DEFAULT_BASE_URL = "https://api.blur.io"

    def __init__(
        self,
        auth_token: Optional[str] = None,
        base_url: str = DEFAULT_BASE_URL,
        requests_per_second: float = 8.0,
        retry_config: Optional[RetryConfig] = None,
        circuit_breaker_config: Optional[CircuitBreakerConfig] = None,
        custom_http_client: Optional[Callable[..., Any]] = None,
    ):
        super().__init__(
            marketplace=Marketplace.BLUR,
            base_url=base_url,
            api_key=auth_token,
            requests_per_second=requests_per_second,
            retry_config=retry_config,
            circuit_breaker_config=circuit_breaker_config,
            custom_http_client=custom_http_client,
        )

    def get_headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/json",
            "User-Agent": "Lux-Blur-Connector/1.0",
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
            headers["blur-auth"] = self.api_key
        return headers

    def get_floor_price(self, collection_address: str) -> FloorPriceQuote:
        if not collection_address:
            raise ValidationError("collection_address is required", marketplace=self.marketplace.value)

        addr = collection_address.lower()
        data = self.request(f"/v1/collections/{addr}")
        col = data.get("collection", data)

        floor_price_data = col.get("floorPrice", {})
        if isinstance(floor_price_data, dict):
            floor_amount_raw = floor_price_data.get("amount", 0.0)
            floor_price_eth = float(floor_amount_raw)
            if floor_price_eth > 1e10:
                floor_price_eth /= 1e18
            currency = floor_price_data.get("unit", "ETH")
        elif isinstance(floor_price_data, (int, float, str)):
            floor_price_eth = float(floor_price_data)
            if floor_price_eth > 1e10:
                floor_price_eth /= 1e18
            currency = "ETH"
        else:
            floor_price_eth = 0.0
            currency = "ETH"

        best_token_id = str(col.get("bestFloorTokenId", "0"))

        return FloorPriceQuote(
            marketplace=Marketplace.BLUR,
            collection_address=addr,
            floor_price_eth=floor_price_eth,
            floor_price_usd=floor_price_eth * 3000.0,
            currency=currency,
            token_id=best_token_id if best_token_id != "0" else None,
            listing_url=f"https://blur.io/collection/{addr}",
            timestamp=time.time(),
        )

    def get_collection_stats(self, collection_address: str) -> CollectionStats:
        if not collection_address:
            raise ValidationError("collection_address is required", marketplace=self.marketplace.value)

        addr = collection_address.lower()
        data = self.request(f"/v1/collections/{addr}")
        col = data.get("collection", data)

        floor_price_obj = col.get("floorPrice", {})
        floor_eth = 0.0
        if isinstance(floor_price_obj, dict):
            floor_eth = float(floor_price_obj.get("amount", 0.0) or 0.0)
            if floor_eth > 1e10:
                floor_eth /= 1e18
        elif isinstance(floor_price_obj, (int, float, str)):
            floor_eth = float(floor_price_obj or 0.0)
            if floor_eth > 1e10:
                floor_eth /= 1e18

        vol_1d = float(col.get("volumeOneDay", {}).get("amount", 0.0) if isinstance(col.get("volumeOneDay"), dict) else col.get("volumeOneDay", 0.0) or 0.0)
        vol_7d = float(col.get("volumeOneWeek", {}).get("amount", 0.0) if isinstance(col.get("volumeOneWeek"), dict) else col.get("volumeOneWeek", 0.0) or 0.0)
        vol_total = float(col.get("volumeAllTime", {}).get("amount", 0.0) if isinstance(col.get("volumeAllTime"), dict) else col.get("volumeAllTime", 0.0) or 0.0)

        # Normalize wei if required
        if vol_1d > 1e10:
            vol_1d /= 1e18
        if vol_7d > 1e10:
            vol_7d /= 1e18
        if vol_total > 1e10:
            vol_total /= 1e18

        total_supply = int(col.get("totalSupply", 0) or 0)
        num_owners = int(col.get("numberOwners", 0) or 0)

        return CollectionStats(
            collection_address=addr,
            name=col.get("name", addr),
            symbol=col.get("symbol"),
            total_supply=total_supply,
            num_owners=num_owners,
            floor_price_eth=floor_eth,
            floor_price_usd=floor_eth * 3000.0,
            volume_1h_eth=vol_1d / 24.0,
            volume_24h_eth=vol_1d,
            volume_7d_eth=vol_7d,
            volume_30d_eth=vol_7d * 4.0,
            volume_total_eth=vol_total,
            sales_1h=int(col.get("salesOneDay", 0) or 0) // 24,
            sales_24h=int(col.get("salesOneDay", 0) or 0),
            sales_7d=int(col.get("salesOneWeek", 0) or 0),
            sales_30d=int(col.get("salesOneMonth", 0) or 0),
            sales_total=int(col.get("salesAllTime", 0) or 0),
            average_price_24h_eth=(vol_1d / max(1, int(col.get("salesOneDay", 0) or 0))) if vol_1d > 0 else 0.0,
            market_cap_eth=floor_eth * total_supply,
            timestamp=time.time(),
        )

    def get_recent_sales(
        self, collection_address: str, limit: int = 50, cursor: Optional[str] = None
    ) -> List[SaleEvent]:
        addr = collection_address.lower()
        params: Dict[str, Any] = {
            "collectionAddress": addr,
            "filters": json.dumps({"activityTypes": ["SALE"]}),
        }
        if cursor:
            params["cursor"] = cursor

        data = self.request("/v1/activity", params=params)
        activities = data.get("activities", data.get("events", []))

        sales: List[SaleEvent] = []
        for act in activities[:limit]:
            try:
                price_data = act.get("price", {})
                if isinstance(price_data, dict):
                    price_val = float(price_data.get("amount", 0.0) or 0.0)
                    currency = price_data.get("unit", "ETH")
                else:
                    price_val = float(price_data or 0.0)
                    currency = "ETH"

                if price_val > 1e10:
                    price_val /= 1e18

                token_id = str(act.get("tokenId", "0"))
                tx_hash = act.get("txHash", "")
                created_at = act.get("createdAt", time.time())
                if isinstance(created_at, str):
                    try:
                        import dateutil.parser
                        created_at = dateutil.parser.parse(created_at).timestamp()
                    except Exception:
                        created_at = time.time()

                sale = SaleEvent(
                    event_id=str(act.get("id", f"blur_{tx_hash}_{token_id}_{created_at}")),
                    marketplace=Marketplace.BLUR,
                    collection_address=addr,
                    token_id=token_id,
                    price_raw=str(act.get("price", "0")),
                    price_eth=price_val,
                    price_usd=price_val * 3000.0,
                    payment_token=currency,
                    buyer_address=str(act.get("toAddress", act.get("buyer", ""))).lower(),
                    seller_address=str(act.get("fromAddress", act.get("seller", ""))).lower(),
                    transaction_hash=str(tx_hash),
                    block_number=int(act.get("blockNumber", 0) or 0),
                    timestamp=float(created_at),
                    event_type=EventType.SALE,
                    fee_breakdown=FeeBreakdown(
                        marketplace_fee_percent=0.0,  # Blur has 0% marketplace fee
                        creator_fee_percent=0.5,
                        marketplace_fee_eth=0.0,
                        creator_fee_eth=price_val * 0.005,
                    ),
                    token_name=f"#{token_id}",
                    raw_event=act,
                )
                sales.append(sale)
            except Exception as e:
                logger.warning(f"Error parsing Blur activity event: {e}")
                continue

        return sales

    def get_token_metadata(self, collection_address: str, token_id: str) -> TokenMetadata:
        addr = collection_address.lower()
        data = self.request(f"/v1/collections/{addr}/tokens/{token_id}")
        token_info = data.get("token", data)

        traits_raw = token_info.get("traits", []) or []
        attributes: List[TraitAttribute] = []
        for tr in traits_raw:
            attributes.append(
                TraitAttribute(
                    trait_type=str(tr.get("traitType", tr.get("type", "trait"))),
                    value=tr.get("value", ""),
                )
            )

        return TokenMetadata(
            token_id=str(token_id),
            collection_address=addr,
            name=token_info.get("name", f"#{token_id}"),
            image_url=token_info.get("imageUrl"),
            attributes=attributes,
            raw_metadata=token_info,
        )
