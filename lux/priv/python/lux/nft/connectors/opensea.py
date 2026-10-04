"""
OpenSea API v2 Connector with rate-limiting, retries, and schema normalization.
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


class OpenSeaConnector(BaseMarketplaceConnector):
    """
    OpenSea API v2 Connector.
    Provides collection statistics, floor prices, live sales, and NFT metadata.
    """

    DEFAULT_BASE_URL = "https://api.opensea.io"

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: str = DEFAULT_BASE_URL,
        chain: str = "ethereum",
        requests_per_second: float = 4.0,
        retry_config: Optional[RetryConfig] = None,
        circuit_breaker_config: Optional[CircuitBreakerConfig] = None,
        custom_http_client: Optional[Callable[..., Any]] = None,
    ):
        super().__init__(
            marketplace=Marketplace.OPENSEA,
            base_url=base_url,
            api_key=api_key,
            requests_per_second=requests_per_second,
            retry_config=retry_config,
            circuit_breaker_config=circuit_breaker_config,
            custom_http_client=custom_http_client,
        )
        self.chain = chain.lower()

    def get_headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/json",
            "User-Agent": "Lux-NFT-Aggregator/1.0",
        }
        if self.api_key:
            headers["x-api-key"] = self.api_key
        return headers

    def get_floor_price(self, collection_slug_or_address: str) -> FloorPriceQuote:
        if not collection_slug_or_address:
            raise ValidationError("collection_slug_or_address is required", marketplace=self.marketplace.value)

        # Query OpenSea collection endpoint
        if collection_slug_or_address.startswith("0x"):
            endpoint = f"/api/v2/chain/{self.chain}/contract/{collection_slug_or_address}"
            data = self.request(endpoint)
            collection_slug = data.get("collection", collection_slug_or_address)
        else:
            collection_slug = collection_slug_or_address

        # Get collection stats for accurate floor price
        stats_endpoint = f"/api/v2/collections/{collection_slug}/stats"
        stats_data = self.request(stats_endpoint)
        total_stats = stats_data.get("total", {})

        floor_price_eth = float(total_stats.get("floor_price", 0.0) or 0.0)
        floor_price_usd = float(total_stats.get("floor_price_usd", 0.0) or 0.0)
        if floor_price_usd == 0.0 and floor_price_eth > 0.0:
            # Fallback estimation if USD is omitted
            floor_price_usd = floor_price_eth * 3000.0

        return FloorPriceQuote(
            marketplace=Marketplace.OPENSEA,
            collection_address=collection_slug_or_address.lower(),
            floor_price_eth=floor_price_eth,
            floor_price_usd=floor_price_usd,
            currency="ETH",
            listing_url=f"https://opensea.io/collection/{collection_slug}",
            timestamp=time.time(),
        )

    def get_collection_stats(self, collection_slug_or_address: str) -> CollectionStats:
        if not collection_slug_or_address:
            raise ValidationError("collection_slug_or_address is required", marketplace=self.marketplace.value)

        collection_slug = collection_slug_or_address
        if collection_slug_or_address.startswith("0x"):
            contract_data = self.request(f"/api/v2/chain/{self.chain}/contract/{collection_slug_or_address}")
            collection_slug = contract_data.get("collection", collection_slug_or_address)

        stats_data = self.request(f"/api/v2/collections/{collection_slug}/stats")
        total = stats_data.get("total", {})
        intervals = stats_data.get("intervals", [])

        int_1h = next((i for i in intervals if i.get("interval") == "one_hour"), {})
        int_24h = next((i for i in intervals if i.get("interval") == "one_day"), {})
        int_7d = next((i for i in intervals if i.get("interval") == "seven_day"), {})
        int_30d = next((i for i in intervals if i.get("interval") == "thirty_day"), {})

        floor_eth = float(total.get("floor_price", 0.0) or 0.0)
        floor_usd = float(total.get("floor_price_usd", 0.0) or 0.0)
        supply = int(total.get("supply", 0) or 0)
        num_owners = int(total.get("num_owners", 0) or 0)
        market_cap = float(total.get("market_cap", 0.0) or (floor_eth * supply))

        return CollectionStats(
            collection_address=collection_slug_or_address.lower(),
            name=collection_slug,
            total_supply=supply,
            num_owners=num_owners,
            floor_price_eth=floor_eth,
            floor_price_usd=floor_usd,
            volume_1h_eth=float(int_1h.get("volume", 0.0) or 0.0),
            volume_24h_eth=float(int_24h.get("volume", 0.0) or 0.0),
            volume_7d_eth=float(int_7d.get("volume", 0.0) or 0.0),
            volume_30d_eth=float(int_30d.get("volume", 0.0) or 0.0),
            volume_total_eth=float(total.get("volume", 0.0) or 0.0),
            sales_1h=int(int_1h.get("sales", 0) or 0),
            sales_24h=int(int_24h.get("sales", 0) or 0),
            sales_7d=int(int_7d.get("sales", 0) or 0),
            sales_30d=int(int_30d.get("sales", 0) or 0),
            sales_total=int(total.get("sales", 0) or 0),
            average_price_24h_eth=float(int_24h.get("average_price", 0.0) or 0.0),
            market_cap_eth=market_cap,
            timestamp=time.time(),
        )

    def get_recent_sales(
        self, collection_slug_or_address: str, limit: int = 50, cursor: Optional[str] = None
    ) -> List[SaleEvent]:
        collection_slug = collection_slug_or_address
        if collection_slug_or_address.startswith("0x"):
            contract_data = self.request(f"/api/v2/chain/{self.chain}/contract/{collection_slug_or_address}")
            collection_slug = contract_data.get("collection", collection_slug_or_address)

        params: Dict[str, Any] = {
            "event_type": "sale",
            "limit": min(limit, 100),
        }
        if cursor:
            params["next"] = cursor

        data = self.request(f"/api/v2/events/collection/{collection_slug}", params=params)
        events_raw = data.get("asset_events", []) or data.get("events", [])

        normalized_sales: List[SaleEvent] = []
        for ev in events_raw:
            try:
                # Extract payment & price
                payment = ev.get("payment", {}) or {}
                price_eth = float(payment.get("quantity", 0.0) or 0.0)
                symbol = payment.get("symbol", "ETH")
                if symbol == "ETH" or symbol == "WETH":
                    # Some payloads format price in decimals
                    decimals = int(payment.get("decimals", 18) or 18)
                    if price_eth > 1e10:  # In wei
                        price_eth = price_eth / (10 ** decimals)

                # Extract token info
                nft = ev.get("nft", {}) or {}
                token_id = str(nft.get("identifier", ev.get("token_id", "0")))
                contract = nft.get("contract", collection_slug_or_address)

                # Buyer / seller
                buyer = ev.get("buyer", ev.get("winner_account", {}).get("address", ""))
                seller = ev.get("seller", ev.get("seller_account", {}).get("address", ""))
                tx_hash = ev.get("transaction", ev.get("transaction_hash", ""))
                event_ts = ev.get("event_timestamp", time.time())
                if isinstance(event_ts, str):
                    try:
                        import dateutil.parser
                        event_ts = dateutil.parser.parse(event_ts).timestamp()
                    except Exception:
                        event_ts = time.time()

                fee_details = ev.get("fees", []) or []
                mkt_fee = sum(float(f.get("amount", 0.0)) for f in fee_details if f.get("fee_type") == "protocol")
                creator_fee = sum(float(f.get("amount", 0.0)) for f in fee_details if f.get("fee_type") == "creator")

                sale = SaleEvent(
                    event_id=str(ev.get("id", f"opensea_{tx_hash}_{token_id}_{event_ts}")),
                    marketplace=Marketplace.OPENSEA,
                    collection_address=str(contract).lower(),
                    token_id=token_id,
                    price_raw=str(payment.get("quantity", "0")),
                    price_eth=price_eth,
                    price_usd=price_eth * 3000.0,
                    payment_token=symbol,
                    buyer_address=str(buyer).lower(),
                    seller_address=str(seller).lower(),
                    transaction_hash=str(tx_hash),
                    block_number=int(ev.get("block_number", 0) or 0),
                    timestamp=float(event_ts),
                    event_type=EventType.SALE,
                    fee_breakdown=FeeBreakdown(
                        marketplace_fee_percent=0.5,
                        creator_fee_percent=creator_fee,
                        marketplace_fee_eth=mkt_fee,
                        creator_fee_eth=creator_fee,
                    ),
                    token_name=nft.get("name"),
                    image_url=nft.get("image_url"),
                    raw_event=ev,
                )
                normalized_sales.append(sale)
            except Exception as e:
                logger.warning(f"Error parsing OpenSea sale event: {e}")
                continue

        return normalized_sales

    def get_token_metadata(self, collection_address: str, token_id: str) -> TokenMetadata:
        endpoint = f"/api/v2/chain/{self.chain}/contract/{collection_address}/nfts/{token_id}"
        data = self.request(endpoint)
        nft = data.get("nft", {}) or {}

        traits_raw = nft.get("traits", []) or []
        attributes: List[TraitAttribute] = []
        for tr in traits_raw:
            trait_type = tr.get("trait_type", "attribute")
            val = tr.get("value", "")
            attributes.append(TraitAttribute(trait_type=str(trait_type), value=val))

        return TokenMetadata(
            token_id=str(token_id),
            collection_address=collection_address.lower(),
            name=nft.get("name"),
            image_url=nft.get("image_url"),
            attributes=attributes,
            raw_metadata=nft,
        )
