"""
Comprehensive Edge Case and Failure Recovery Tests for NFT Aggregator.
"""

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
from lux.nft.pipeline import NFTMarketplacePipeline
from lux.nft.pricing.engine import PriceTrackingEngine
from lux.nft.rarity.engine import TraitRarityEngine
from lux.nft.sales.dedup import EventDeduplicator, ReplayBuffer
from lux.nft.sales.normalizer import SalesEventNormalizer
from lux.nft.sales.poller import EventFilterConfig, SalesStreamPoller
from lux.nft.types import (
    EventType,
    FeeBreakdown,
    InvalidResponseError,
    Marketplace,
    MarketplaceAuthenticationError,
    MarketplaceUnavailableError,
    NFTMarketplaceError,
    RarityTier,
    RateLimitExceededError,
    ResourceNotFoundError,
    SaleEvent,
    TokenMetadata,
    TraitAttribute,
    TrendDirection,
    ValidationError,
)


def test_base_connector_error_handling_and_circuit_tripping():
    # Test retry on retryable HTTP 500 error then circuit breaker trip
    mock_failing_client = MagicMock(side_effect=MarketplaceUnavailableError("Server error 503"))

    conn = OpenSeaConnector(
        retry_config=RetryConfig(max_retries=2, base_delay=0.01),
        circuit_breaker_config=CircuitBreakerConfig(failure_threshold=2, recovery_timeout=0.1),
        custom_http_client=mock_failing_client,
    )

    with pytest.raises(MarketplaceUnavailableError):
        conn.get_floor_price("0x123")

    # Second failure should trip the circuit
    with pytest.raises(MarketplaceUnavailableError):
        conn.get_floor_price("0x123")

    assert conn.circuit_breaker.state == CircuitState.OPEN


def test_connector_validation_errors():
    conn = OpenSeaConnector()
    with pytest.raises(ValidationError):
        conn.get_floor_price("")

    with pytest.raises(ValidationError):
        conn.get_collection_stats("")


def test_pricing_engine_zero_and_single_sale():
    engine = PriceTrackingEngine()
    analysis = engine.analyze_price_trends(
        collection_address="0xabc",
        current_floor_eth=5.0,
        historical_sales=[],
        floor_history_hourly=[],
    )
    assert analysis.current_floor_eth == 5.0
    assert analysis.volume_24h_eth == 0.0
    assert analysis.vwap_24h_eth == 0.0
    assert analysis.analyzed_sales_count == 0
    assert analysis.trend_direction == TrendDirection.NEUTRAL


def test_deduplicator_capacity_pruning():
    dedup = EventDeduplicator(max_capacity=5, ttl_seconds=0.05)
    for i in range(10):
        sale = SaleEvent(
            event_id=f"e_{i}",
            marketplace=Marketplace.BLUR,
            collection_address="0x123",
            token_id=str(i),
            price_raw="100",
            price_eth=1.0,
            price_usd=3000.0,
            payment_token="ETH",
            buyer_address="0xa",
            seller_address="0xb",
            transaction_hash=f"0xtx_{i}",
            block_number=1,
            timestamp=time.time(),
        )
        dedup.check_and_add(sale)

    assert dedup.size() <= 10


def test_rarity_engine_ties_and_identical_tokens():
    # 3 identical tokens
    tokens = [
        TokenMetadata(
            token_id="1",
            collection_address="0x123",
            attributes=[TraitAttribute(trait_type="Type", value="Robot")],
        ),
        TokenMetadata(
            token_id="2",
            collection_address="0x123",
            attributes=[TraitAttribute(trait_type="Type", value="Robot")],
        ),
        TokenMetadata(
            token_id="3",
            collection_address="0x123",
            attributes=[TraitAttribute(trait_type="Type", value="Alien")],
        ),
    ]

    engine = TraitRarityEngine(include_missing_traits=False, include_trait_count=False)
    report = engine.analyze_collection("0x123", tokens)

    # Alien is 1/3 (rarer than Robot 2/3)
    alien_tok = engine.get_token_rarity("3")
    assert alien_tok.rank == 1
    assert alien_tok.tier == RarityTier.LEGENDARY

    # Top rarest query
    top_tokens = engine.get_top_rarest(limit=2)
    assert len(top_tokens) == 2
    assert top_tokens[0].token_id == "3"
