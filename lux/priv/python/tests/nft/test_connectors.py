"""
Unit and Integration tests for NFT Marketplace Connectors and Rate Limiting.
"""

import json
import time
import pytest
from unittest.mock import MagicMock

from lux.nft.connectors.aggregator import MultiMarketplaceAggregator
from lux.nft.connectors.base import (
    BaseMarketplaceConnector,
    CircuitBreaker,
    CircuitBreakerConfig,
    CircuitState,
    RetryConfig,
    TokenBucketRateLimiter,
)
from lux.nft.connectors.blur import BlurConnector
from lux.nft.connectors.looksrare import LooksRareConnector
from lux.nft.connectors.opensea import OpenSeaConnector
from lux.nft.types import (
    InvalidResponseError,
    Marketplace,
    MarketplaceAuthenticationError,
    MarketplaceUnavailableError,
    RateLimitExceededError,
    ResourceNotFoundError,
    ValidationError,
)


def test_token_bucket_rate_limiter_basic():
    limiter = TokenBucketRateLimiter(requests_per_second=10.0, burst_capacity=2.0)
    assert limiter.acquire(1.0)
    assert limiter.acquire(1.0)
    # Burst exhausted, next immediate acquire should block slightly or succeed with wait
    t0 = time.time()
    assert limiter.acquire(1.0, max_wait=0.5)
    t1 = time.time()
    assert t1 - t0 >= 0.05  # had to wait for refill


def test_circuit_breaker_transitions():
    cfg = CircuitBreakerConfig(failure_threshold=3, recovery_timeout=0.2, half_open_success_threshold=2)
    cb = CircuitBreaker("test", config=cfg)
    assert cb.state == CircuitState.CLOSED
    assert cb.allow_request()

    cb.record_failure()
    cb.record_failure()
    assert cb.state == CircuitState.CLOSED

    cb.record_failure()
    assert cb.state == CircuitState.OPEN
    assert not cb.allow_request()

    # Wait for recovery timeout
    time.sleep(0.25)
    assert cb.state == CircuitState.HALF_OPEN
    assert cb.allow_request()

    cb.record_success()
    assert cb.state == CircuitState.HALF_OPEN
    cb.record_success()
    assert cb.state == CircuitState.CLOSED


def test_opensea_connector_floor_price_and_stats():
    mock_responses = {
        "/api/v2/chain/ethereum/contract/0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d": {
            "collection": "boredapeyachtclub"
        },
        "/api/v2/collections/boredapeyachtclub/stats": {
            "total": {
                "floor_price": 12.5,
                "floor_price_usd": 37500.0,
                "supply": 10000,
                "num_owners": 5500,
                "volume": 850000.0,
                "sales": 32000,
            },
            "intervals": [
                {"interval": "one_hour", "volume": 15.0, "sales": 1},
                {"interval": "one_day", "volume": 120.0, "sales": 10, "average_price": 12.0},
                {"interval": "seven_day", "volume": 800.0, "sales": 65},
                {"interval": "thirty_day", "volume": 3200.0, "sales": 260},
            ],
        },
    }

    def mock_http(url, **kwargs):
        for path, resp in mock_responses.items():
            if path in url:
                return resp
        return {}

    conn = OpenSeaConnector(api_key="test_key", custom_http_client=mock_http)
    assert conn.get_headers()["x-api-key"] == "test_key"

    quote = conn.get_floor_price("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert quote.marketplace == Marketplace.OPENSEA
    assert quote.floor_price_eth == 12.5
    assert quote.floor_price_usd == 37500.0

    stats = conn.get_collection_stats("boredapeyachtclub")
    assert stats.total_supply == 10000
    assert stats.floor_price_eth == 12.5
    assert stats.volume_24h_eth == 120.0
    assert stats.sales_24h == 10


def test_opensea_connector_recent_sales():
    mock_events = {
        "asset_events": [
            {
                "id": "os_evt_101",
                "nft": {
                    "identifier": "1234",
                    "contract": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
                    "name": "BAYC #1234",
                    "image_url": "https://example.com/1234.png",
                },
                "payment": {
                    "quantity": "12500000000000000000",
                    "decimals": 18,
                    "symbol": "ETH",
                },
                "buyer": "0x1111111111111111111111111111111111111111",
                "seller": "0x2222222222222222222222222222222222222222",
                "transaction": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
                "block_number": 19000000,
                "event_timestamp": 1700000000,
                "fees": [
                    {"fee_type": "protocol", "amount": "0.0625"},
                    {"fee_type": "creator", "amount": "0.3125"},
                ],
            }
        ]
    }

    conn = OpenSeaConnector(custom_http_client=lambda url, **kwargs: mock_events)
    sales = conn.get_recent_sales("boredapeyachtclub", limit=10)
    assert len(sales) == 1
    s = sales[0]
    assert s.marketplace == Marketplace.OPENSEA
    assert s.token_id == "1234"
    assert s.price_eth == 12.5
    assert s.buyer_address == "0x1111111111111111111111111111111111111111"
    assert s.transaction_hash == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"


def test_blur_connector_floor_stats_and_activity():
    mock_blur = {
        "/v1/collections/0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d": {
            "collection": {
                "name": "Bored Ape Yacht Club",
                "totalSupply": 10000,
                "numberOwners": 5500,
                "floorPrice": {"amount": "12.45", "unit": "ETH"},
                "bestFloorTokenId": "5678",
                "volumeOneDay": {"amount": "140.0"},
                "volumeOneWeek": {"amount": "900.0"},
                "volumeAllTime": {"amount": "950000.0"},
                "salesOneDay": 11,
                "salesOneWeek": 72,
                "salesAllTime": 35000,
            }
        },
        "/v1/activity": {
            "activities": [
                {
                    "id": "blur_act_99",
                    "tokenId": "5678",
                    "price": {"amount": "12450000000000000000", "unit": "ETH"},
                    "collectionAddress": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
                    "toAddress": "0x3333333333333333333333333333333333333333",
                    "fromAddress": "0x4444444444444444444444444444444444444444",
                    "txHash": "0x9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef",
                    "blockNumber": 19000100,
                    "createdAt": 1700000050,
                }
            ]
        },
    }

    def mock_http(url, **kwargs):
        for path, resp in mock_blur.items():
            if path in url:
                return resp
        return {}

    conn = BlurConnector(auth_token="blur_token_123", custom_http_client=mock_http)
    assert conn.get_headers()["Authorization"] == "Bearer blur_token_123"

    quote = conn.get_floor_price("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert quote.marketplace == Marketplace.BLUR
    assert quote.floor_price_eth == 12.45
    assert quote.token_id == "5678"

    stats = conn.get_collection_stats("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert stats.volume_24h_eth == 140.0
    assert stats.sales_24h == 11

    sales = conn.get_recent_sales("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d", limit=5)
    assert len(sales) == 1
    assert sales[0].token_id == "5678"
    assert sales[0].price_eth == 12.45


def test_looksrare_connector_floor_stats_and_events():
    mock_lr = {
        "/api/v2/collections/stats": {
            "data": {
                "name": "Bored Ape Yacht Club",
                "floorPrice": "12600000000000000000",
                "volume24h": "35000000000000000000",
                "volume7d": "210000000000000000000",
                "volumeAll": "120000000000000000000000",
                "count24h": 3,
                "count7d": 18,
                "countAll": 8000,
                "totalSupply": 10000,
                "ownerCount": 5500,
            }
        },
        "/api/v2/events": {
            "data": [
                {
                    "id": "lr_evt_50",
                    "collection": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
                    "token": {"tokenId": "9999", "name": "BAYC #9999"},
                    "order": {"price": "12600000000000000000"},
                    "to": "0x5555555555555555555555555555555555555555",
                    "from": "0x6666666666666666666666666666666666666666",
                    "hash": "0x5555555555555555555555555555555555555555555555555555555555555555",
                    "blockNumber": 19000200,
                    "createdAt": 1700000100,
                }
            ]
        },
    }

    def mock_http(url, **kwargs):
        for path, resp in mock_lr.items():
            if path in url:
                return resp
        return {}

    conn = LooksRareConnector(api_key="lr_api_key", custom_http_client=mock_http)
    assert conn.get_headers()["X-LOOKSRARE-API-KEY"] == "lr_api_key"

    quote = conn.get_floor_price("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert quote.marketplace == Marketplace.LOOKSRARE
    assert quote.floor_price_eth == 12.6

    sales = conn.get_recent_sales("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d", limit=5)
    assert len(sales) == 1
    assert sales[0].token_id == "9999"
    assert sales[0].price_eth == 12.6


def test_multi_marketplace_aggregator_cross_venue_spread():
    # Setup mock connectors with differing floors
    # OpenSea: 12.5 ETH
    # Blur: 12.45 ETH (Lowest / Best)
    # LooksRare: 12.60 ETH
    os_conn = OpenSeaConnector(custom_http_client=lambda url, **kw: {
        "total": {"floor_price": 12.5, "floor_price_usd": 37500.0, "supply": 10000, "volume": 100.0, "sales": 8},
        "intervals": [{"interval": "one_day", "volume": 100.0, "sales": 8}],
    })
    blur_conn = BlurConnector(custom_http_client=lambda url, **kw: {
        "collection": {"floorPrice": {"amount": "12.45"}, "volumeOneDay": {"amount": "140.0"}, "salesOneDay": 11, "totalSupply": 10000}
    })
    lr_conn = LooksRareConnector(custom_http_client=lambda url, **kw: {
        "data": {"floorPrice": "12600000000000000000", "volume24h": "35000000000000000000", "count24h": 3, "totalSupply": 10000}
    })

    aggregator = MultiMarketplaceAggregator(
        opensea_connector=os_conn,
        blur_connector=blur_conn,
        looksrare_connector=lr_conn,
    )

    agg_floor = aggregator.get_aggregated_floor_price("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert agg_floor.best_marketplace == Marketplace.BLUR
    assert agg_floor.best_floor_price_eth == 12.45
    assert len(agg_floor.quotes) == 3
    assert round(agg_floor.spread_eth, 4) == round(12.60 - 12.45, 4)
    assert agg_floor.spread_percent > 0

    agg_stats = aggregator.get_aggregated_stats("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert agg_stats.floor_price_eth == 12.45
    assert agg_stats.volume_24h_eth == 100.0 + 140.0 + 35.0
    assert agg_stats.sales_24h == 8 + 11 + 3


def test_aggregator_resilience_when_venues_fail():
    # If OpenSea and LooksRare fail with exceptions, Blur should still provide results
    failing_os = OpenSeaConnector(custom_http_client=MagicMock(side_effect=MarketplaceUnavailableError("OS Down")))
    failing_lr = LooksRareConnector(custom_http_client=MagicMock(side_effect=RateLimitExceededError("LR 429")))
    working_blur = BlurConnector(custom_http_client=lambda url, **kw: {
        "collection": {"floorPrice": {"amount": "12.45"}, "volumeOneDay": {"amount": "140.0"}, "salesOneDay": 11, "totalSupply": 10000}
    })

    aggregator = MultiMarketplaceAggregator(
        opensea_connector=failing_os,
        blur_connector=working_blur,
        looksrare_connector=failing_lr,
    )

    agg_floor = aggregator.get_aggregated_floor_price("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")
    assert agg_floor.best_marketplace == Marketplace.BLUR
    assert agg_floor.best_floor_price_eth == 12.45
    assert len(agg_floor.quotes) == 1
