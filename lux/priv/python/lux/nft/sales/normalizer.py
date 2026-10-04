"""
Sales Event Normalizer for Multi-Marketplace NFT Transactions.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, Optional
import time

from lux.nft.types import (
    EventType,
    FeeBreakdown,
    Marketplace,
    SaleEvent,
    ValidationError,
)

logger = logging.getLogger(__name__)


class SalesEventNormalizer:
    """
    Standardizes disparate marketplace event payloads into canonical SaleEvent objects.
    Handles currency units, fee breakdowns, timestamp conversions, and address formatting.
    """

    def __init__(self, eth_usd_rate: float = 3000.0):
        self.eth_usd_rate = eth_usd_rate

    def normalize(self, raw_data: Dict[str, Any], marketplace: Optional[Marketplace] = None) -> SaleEvent:
        """Dispatches normalization based on marketplace or auto-detects payload format."""
        if marketplace == Marketplace.OPENSEA or "asset_events" in raw_data or "is_private" in raw_data:
            return self._normalize_opensea(raw_data)
        elif marketplace == Marketplace.BLUR or "activityTypes" in raw_data or "fromAddress" in raw_data:
            return self._normalize_blur(raw_data)
        elif marketplace == Marketplace.LOOKSRARE or "looksrare" in str(raw_data).lower():
            return self._normalize_looksrare(raw_data)
        else:
            return self._normalize_generic(raw_data)

    def _normalize_opensea(self, data: Dict[str, Any]) -> SaleEvent:
        nft = data.get("nft", {}) or {}
        payment = data.get("payment", {}) or {}

        price_raw = str(payment.get("quantity", data.get("total_price", "0")))
        price_eth = float(price_raw)
        decimals = int(payment.get("decimals", 18) or 18)
        if price_eth > 1e10:
            price_eth /= 10 ** decimals

        token_id = str(nft.get("identifier", data.get("token_id", "0")))
        contract = str(nft.get("contract", data.get("asset_contract", {}).get("address", ""))).lower()
        tx_hash = str(data.get("transaction", data.get("transaction_hash", "")))

        event_ts = data.get("event_timestamp", time.time())
        if isinstance(event_ts, str):
            try:
                import dateutil.parser
                event_ts = dateutil.parser.parse(event_ts).timestamp()
            except Exception:
                event_ts = time.time()

        fees = data.get("fees", []) or []
        mkt_fee = sum(float(f.get("amount", 0.0)) for f in fees if f.get("fee_type") == "protocol")
        creator_fee = sum(float(f.get("amount", 0.0)) for f in fees if f.get("fee_type") == "creator")

        return SaleEvent(
            event_id=str(data.get("id", f"opensea_{tx_hash}_{token_id}_{event_ts}")),
            marketplace=Marketplace.OPENSEA,
            collection_address=contract,
            token_id=token_id,
            price_raw=price_raw,
            price_eth=round(price_eth, 6),
            price_usd=round(price_eth * self.eth_usd_rate, 2),
            payment_token=str(payment.get("symbol", "ETH")),
            buyer_address=str(data.get("buyer", data.get("winner_account", {}).get("address", ""))).lower(),
            seller_address=str(data.get("seller", data.get("seller_account", {}).get("address", ""))).lower(),
            transaction_hash=tx_hash,
            block_number=int(data.get("block_number", 0) or 0),
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
            raw_event=data,
        )

    def _normalize_blur(self, data: Dict[str, Any]) -> SaleEvent:
        price_data = data.get("price", {})
        if isinstance(price_data, dict):
            price_raw = str(price_data.get("amount", "0"))
            currency = price_data.get("unit", "ETH")
        else:
            price_raw = str(data.get("price", "0"))
            currency = "ETH"

        price_eth = float(price_raw)
        if price_eth > 1e10:
            price_eth /= 1e18

        token_id = str(data.get("tokenId", "0"))
        contract = str(data.get("collectionAddress", data.get("contractAddress", ""))).lower()
        tx_hash = str(data.get("txHash", ""))

        event_ts = data.get("createdAt", time.time())
        if isinstance(event_ts, str):
            try:
                import dateutil.parser
                event_ts = dateutil.parser.parse(event_ts).timestamp()
            except Exception:
                event_ts = time.time()

        return SaleEvent(
            event_id=str(data.get("id", f"blur_{tx_hash}_{token_id}_{event_ts}")),
            marketplace=Marketplace.BLUR,
            collection_address=contract,
            token_id=token_id,
            price_raw=price_raw,
            price_eth=round(price_eth, 6),
            price_usd=round(price_eth * self.eth_usd_rate, 2),
            payment_token=currency,
            buyer_address=str(data.get("toAddress", data.get("buyer", ""))).lower(),
            seller_address=str(data.get("fromAddress", data.get("seller", ""))).lower(),
            transaction_hash=tx_hash,
            block_number=int(data.get("blockNumber", 0) or 0),
            timestamp=float(event_ts),
            event_type=EventType.SALE,
            fee_breakdown=FeeBreakdown(
                marketplace_fee_percent=0.0,
                creator_fee_percent=0.5,
                marketplace_fee_eth=0.0,
                creator_fee_eth=price_eth * 0.005,
            ),
            token_name=f"#{token_id}",
            raw_event=data,
        )

    def _normalize_looksrare(self, data: Dict[str, Any]) -> SaleEvent:
        order = data.get("order", {}) or {}
        price_raw = str(order.get("price", data.get("price", "0")))
        price_eth = float(price_raw)
        if price_eth > 1e10:
            price_eth /= 1e18

        token = data.get("token", {}) or {}
        token_id = str(token.get("tokenId", data.get("tokenId", "0")))
        contract = str(data.get("collection", token.get("collectionAddress", ""))).lower()
        tx_hash = str(data.get("hash", data.get("txHash", "")))

        event_ts = data.get("createdAt", time.time())
        if isinstance(event_ts, str):
            try:
                import dateutil.parser
                event_ts = dateutil.parser.parse(event_ts).timestamp()
            except Exception:
                event_ts = time.time()

        return SaleEvent(
            event_id=str(data.get("id", f"looksrare_{tx_hash}_{token_id}_{event_ts}")),
            marketplace=Marketplace.LOOKSRARE,
            collection_address=contract,
            token_id=token_id,
            price_raw=price_raw,
            price_eth=round(price_eth, 6),
            price_usd=round(price_eth * self.eth_usd_rate, 2),
            payment_token="ETH",
            buyer_address=str(data.get("to", data.get("buyer", ""))).lower(),
            seller_address=str(data.get("from", data.get("seller", ""))).lower(),
            transaction_hash=tx_hash,
            block_number=int(data.get("blockNumber", 0) or 0),
            timestamp=float(event_ts),
            event_type=EventType.SALE,
            fee_breakdown=FeeBreakdown(
                marketplace_fee_percent=0.5,
                creator_fee_percent=0.5,
                marketplace_fee_eth=price_eth * 0.005,
                creator_fee_eth=price_eth * 0.005,
            ),
            token_name=token.get("name"),
            image_url=token.get("imageURI"),
            raw_event=data,
        )

    def _normalize_generic(self, data: Dict[str, Any]) -> SaleEvent:
        price_raw = str(data.get("price_raw", data.get("price", "0")))
        price_eth = float(data.get("price_eth", price_raw) or 0.0)
        if price_eth > 1e10:
            price_eth /= 1e18

        mkt = Marketplace.from_str(str(data.get("marketplace", "unknown")))
        token_id = str(data.get("token_id", data.get("tokenId", "0")))
        contract = str(data.get("collection_address", data.get("contract_address", ""))).lower()
        tx_hash = str(data.get("transaction_hash", data.get("tx_hash", "")))
        event_ts = float(data.get("timestamp", time.time()))

        return SaleEvent(
            event_id=str(data.get("event_id", f"generic_{tx_hash}_{token_id}_{event_ts}")),
            marketplace=mkt,
            collection_address=contract,
            token_id=token_id,
            price_raw=price_raw,
            price_eth=round(price_eth, 6),
            price_usd=round(price_eth * self.eth_usd_rate, 2),
            payment_token=str(data.get("payment_token", "ETH")),
            buyer_address=str(data.get("buyer_address", data.get("buyer", ""))).lower(),
            seller_address=str(data.get("seller_address", data.get("seller", ""))).lower(),
            transaction_hash=tx_hash,
            block_number=int(data.get("block_number", 0) or 0),
            timestamp=event_ts,
            event_type=EventType.from_str(str(data.get("event_type", "sale"))),
            fee_breakdown=FeeBreakdown(),
            token_name=data.get("token_name"),
            image_url=data.get("image_url"),
            raw_event=data,
        )
