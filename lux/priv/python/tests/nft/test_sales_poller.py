"""
Unit and Integration tests for Sales Monitoring, Deduplication, and Normalization.
"""

import time
import pytest
from unittest.mock import MagicMock

from lux.nft.connectors.aggregator import MultiMarketplaceAggregator
from lux.nft.connectors.opensea import OpenSeaConnector
from lux.nft.sales.dedup import EventDeduplicator, ReplayBuffer
from lux.nft.sales.normalizer import SalesEventNormalizer
from lux.nft.sales.poller import EventFilterConfig, SalesStreamPoller
from lux.nft.types import (
    EventType,
    FeeBreakdown,
    Marketplace,
    SaleEvent,
)


def create_sample_sale(event_id: str, price_eth: float, token_id: str = "1", tx_hash: str = "0xaaa") -> SaleEvent:
    return SaleEvent(
        event_id=event_id,
        marketplace=Marketplace.OPENSEA,
        collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        token_id=token_id,
        price_raw=str(int(price_eth * 1e18)),
        price_eth=price_eth,
        price_usd=price_eth * 3000.0,
        payment_token="ETH",
        buyer_address="0x1111111111111111111111111111111111111111",
        seller_address="0x2222222222222222222222222222222222222222",
        transaction_hash=tx_hash,
        block_number=19000000,
        timestamp=time.time(),
        event_type=EventType.SALE,
        fee_breakdown=FeeBreakdown(),
    )


def test_event_deduplicator():
    dedup = EventDeduplicator(max_capacity=100, ttl_seconds=1.0)
    sale1 = create_sample_sale("e1", 10.0, "1", "0x111")
    sale2 = create_sample_sale("e2", 12.0, "2", "0x222")

    assert dedup.check_and_add(sale1) is True
    assert dedup.is_duplicate(sale1) is True
    assert dedup.check_and_add(sale1) is False  # Duplicate

    assert dedup.check_and_add(sale2) is True
    assert dedup.size() == 2

    # Test TTL expiration
    time.sleep(1.1)
    assert dedup.is_duplicate(sale1) is False
    assert dedup.check_and_add(sale1) is True


def test_replay_buffer_querying():
    buf = ReplayBuffer(capacity=10)
    now = time.time()
    s1 = create_sample_sale("e1", 5.0, "10", "0x1")
    s1.timestamp = now - 50
    s2 = create_sample_sale("e2", 15.0, "20", "0x2")
    s2.timestamp = now - 30
    s3 = create_sample_sale("e3", 25.0, "30", "0x3")
    s3.timestamp = now - 10

    buf.extend([s1, s2, s3])
    assert len(buf) == 3

    # Filter by price range
    res_price = buf.query(min_price_eth=10.0, max_price_eth=20.0)
    assert len(res_price) == 1
    assert res_price[0].token_id == "20"

    # Filter by token ID
    res_tok = buf.query(token_id="30")
    assert len(res_tok) == 1
    assert res_tok[0].price_eth == 25.0

    # Filter by since_timestamp
    res_ts = buf.query(since_timestamp=now - 20)
    assert len(res_ts) == 1
    assert res_ts[0].event_id == "e3"


def test_sales_event_normalizer_opensea_blur_looksrare():
    normalizer = SalesEventNormalizer(eth_usd_rate=3000.0)

    # OpenSea payload
    os_raw = {
        "id": "os_99",
        "nft": {"identifier": "777", "contract": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d", "name": "BAYC 777"},
        "payment": {"quantity": "15000000000000000000", "decimals": 18, "symbol": "ETH"},
        "buyer": "0xaaa",
        "seller": "0xbbb",
        "transaction": "0x123",
        "block_number": 19000000,
        "event_timestamp": 1700000000,
        "fees": [{"fee_type": "protocol", "amount": "0.075"}, {"fee_type": "creator", "amount": "0.375"}],
    }
    s_os = normalizer.normalize(os_raw, marketplace=Marketplace.OPENSEA)
    assert s_os.marketplace == Marketplace.OPENSEA
    assert s_os.token_id == "777"
    assert s_os.price_eth == 15.0
    assert s_os.price_usd == 45000.0
    assert s_os.fee_breakdown.creator_fee_percent == 0.375

    # Blur payload
    blur_raw = {
        "id": "blur_88",
        "tokenId": "888",
        "price": {"amount": "14500000000000000000", "unit": "ETH"},
        "collectionAddress": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        "toAddress": "0xccc",
        "fromAddress": "0xddd",
        "txHash": "0x456",
        "blockNumber": 19000050,
        "createdAt": 1700000050,
    }
    s_blur = normalizer.normalize(blur_raw, marketplace=Marketplace.BLUR)
    assert s_blur.marketplace == Marketplace.BLUR
    assert s_blur.token_id == "888"
    assert s_blur.price_eth == 14.5

    # LooksRare payload
    lr_raw = {
        "id": "lr_77",
        "collection": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        "token": {"tokenId": "999", "name": "BAYC 999"},
        "order": {"price": "16000000000000000000"},
        "to": "0xeee",
        "from": "0xfff",
        "hash": "0x789",
        "blockNumber": 19000100,
        "createdAt": 1700000100,
    }
    s_lr = normalizer.normalize(lr_raw, marketplace=Marketplace.LOOKSRARE)
    assert s_lr.marketplace == Marketplace.LOOKSRARE
    assert s_lr.token_id == "999"
    assert s_lr.price_eth == 16.0


def test_sales_stream_poller_filtering_and_whale_dispatch():
    mock_sales = [
        create_sample_sale("e1", 2.0, "1", "0x1"),
        create_sample_sale("e2", 15.0, "2", "0x2"),  # Whale sale (>=10.0 ETH)
        create_sample_sale("e3", 0.5, "3", "0x3"),
    ]

    mock_os = OpenSeaConnector(custom_http_client=lambda url, **kw: {})
    mock_os.get_recent_sales = MagicMock(return_value=mock_sales)

    aggregator = MultiMarketplaceAggregator(opensea_connector=mock_os)
    filter_cfg = EventFilterConfig(min_price_eth=1.0, whale_threshold_eth=10.0)

    poller = SalesStreamPoller(aggregator=aggregator, filter_config=filter_cfg)

    dispatched_sales = []
    whale_alerts = []

    poller.add_subscriber(lambda s: dispatched_sales.append(s))
    poller.add_whale_subscriber(lambda s: whale_alerts.append(s))

    new_sales = poller.poll_once("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")

    # s3 (0.5 ETH) is filtered out because min_price_eth = 1.0
    assert len(new_sales) == 2
    assert len(dispatched_sales) == 2
    assert len(whale_alerts) == 1
    assert whale_alerts[0].price_eth == 15.0
