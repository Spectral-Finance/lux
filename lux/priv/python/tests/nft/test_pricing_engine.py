"""
Unit and Integration tests for Price Tracking Engine & Quantitative Analytics.
"""

import math
import time
import pytest

from lux.nft.pricing.engine import PriceTrackingEngine
from lux.nft.types import (
    EventType,
    FeeBreakdown,
    Marketplace,
    SaleEvent,
    TrendDirection,
)


def create_mock_sale(
    price_eth: float,
    timestamp: float,
    token_id: str = "1",
    marketplace: Marketplace = Marketplace.OPENSEA,
) -> SaleEvent:
    return SaleEvent(
        event_id=f"evt_{token_id}_{timestamp}",
        marketplace=marketplace,
        collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        token_id=token_id,
        price_raw=str(int(price_eth * 1e18)),
        price_eth=price_eth,
        price_usd=price_eth * 3000.0,
        payment_token="ETH",
        buyer_address="0x1111111111111111111111111111111111111111",
        seller_address="0x2222222222222222222222222222222222222222",
        transaction_hash="0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        block_number=19000000,
        timestamp=timestamp,
        event_type=EventType.SALE,
        fee_breakdown=FeeBreakdown(),
    )


def test_iqr_outlier_filtering():
    engine = PriceTrackingEngine(iqr_multiplier=1.5)
    # Normal distribution with extreme manipulation outliers
    prices = [10.0, 10.2, 10.1, 9.9, 10.3, 10.0, 10.1, 10.4, 9.8, 10.2, 0.01, 500.0]
    filtered, outliers_count = engine.filter_price_outliers(prices)
    assert outliers_count == 2
    assert 0.01 not in filtered
    assert 500.0 not in filtered
    assert len(filtered) == 10

    # Test small array edge case
    assert engine.filter_price_outliers([10.0, 20.0])[1] == 0


def test_vwap_calculation():
    engine = PriceTrackingEngine()
    now = time.time()
    sales = [
        create_mock_sale(10.0, now - 100),
        create_mock_sale(12.0, now - 200),
        create_mock_sale(14.0, now - 300),
    ]
    vwap = engine.calculate_vwap(sales)
    assert round(vwap, 4) == 12.0

    assert engine.calculate_vwap([]) == 0.0


def test_moving_averages_sma_ema():
    engine = PriceTrackingEngine()
    prices = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0]

    # SMA 7 over 7 items
    sma_7 = engine.calculate_sma(prices, 7)
    assert round(sma_7, 4) == 13.0

    # SMA with insufficient period
    assert engine.calculate_sma(prices, 10) is None

    # EMA 7
    ema_7 = engine.calculate_ema(prices, 7)
    assert ema_7 is not None
    assert round(ema_7, 4) == 13.0


def test_volatility_calculation():
    engine = PriceTrackingEngine()
    # Constant price -> 0 volatility
    assert engine.calculate_volatility([10.0, 10.0, 10.0, 10.0]) == 0.0

    # Fluctuating prices
    vol = engine.calculate_volatility([10.0, 12.0, 9.0, 14.0, 11.0])
    assert vol > 0.0

    # Insufficient data
    assert engine.calculate_volatility([10.0]) == 0.0


def test_support_resistance_levels():
    engine = PriceTrackingEngine()
    prices = [9.0, 9.5, 10.0, 10.2, 10.5, 11.0, 11.5, 12.0]
    support, resistance = engine.calculate_support_resistance(prices, current_price=10.2)
    assert support < 10.2
    assert resistance > 10.2


def test_trend_classification_breakout_and_dumping():
    engine = PriceTrackingEngine()
    # Breakout: >15% price surge and >30% volume surge
    trend_breakout = engine.classify_trend(
        current_floor=12.0,
        floor_24h_ago=10.0,
        price_change_percent=20.0,
        volume_change_percent=50.0,
        sma_7=11.5,
        sma_24=10.2,
    )
    assert trend_breakout == TrendDirection.BREAKOUT

    # Dumping: <-15% price drop with high volume
    trend_dumping = engine.classify_trend(
        current_floor=8.0,
        floor_24h_ago=10.0,
        price_change_percent=-20.0,
        volume_change_percent=40.0,
        sma_7=8.5,
        sma_24=10.0,
    )
    assert trend_dumping == TrendDirection.DUMPING

    # Bullish moderate trend
    trend_bullish = engine.classify_trend(
        current_floor=10.8,
        floor_24h_ago=10.0,
        price_change_percent=8.0,
        volume_change_percent=10.0,
        sma_7=10.5,
        sma_24=10.1,
    )
    assert trend_bullish == TrendDirection.BULLISH

    # Neutral
    trend_neutral = engine.classify_trend(
        current_floor=10.1,
        floor_24h_ago=10.0,
        price_change_percent=1.0,
        volume_change_percent=2.0,
        sma_7=10.05,
        sma_24=10.05,
    )
    assert trend_neutral == TrendDirection.NEUTRAL


def test_full_price_trend_analysis_integration():
    engine = PriceTrackingEngine()
    ref_time = 1700000000.0

    # Sales in the last 24h: 5 sales total around 10-11 ETH
    sales_curr = [
        create_mock_sale(10.5, ref_time - 3600 * 2, token_id="101"),
        create_mock_sale(10.8, ref_time - 3600 * 6, token_id="102"),
        create_mock_sale(11.0, ref_time - 3600 * 12, token_id="103"),
        create_mock_sale(10.2, ref_time - 3600 * 18, token_id="104"),
        create_mock_sale(10.0, ref_time - 3600 * 22, token_id="105"),
    ]

    # Sales in previous 24h (24h-48h ago): 3 sales around 9-9.5 ETH
    sales_prev = [
        create_mock_sale(9.0, ref_time - 3600 * 26, token_id="91"),
        create_mock_sale(9.2, ref_time - 3600 * 30, token_id="92"),
        create_mock_sale(9.5, ref_time - 3600 * 40, token_id="93"),
    ]

    all_sales = sales_curr + sales_prev
    floor_hourly = [9.0 + (i * 0.08) for i in range(30)]  # 30 hourly datapoints

    analysis = engine.analyze_price_trends(
        collection_address="0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        current_floor_eth=11.0,
        historical_sales=all_sales,
        floor_history_hourly=floor_hourly,
        reference_timestamp=ref_time,
    )

    assert analysis.collection_address == "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
    assert analysis.current_floor_eth == 11.0
    assert analysis.volume_24h_eth == round(10.5 + 10.8 + 11.0 + 10.2 + 10.0, 4)
    assert analysis.volume_24h_ago_eth == round(9.0 + 9.2 + 9.5, 4)
    assert analysis.volume_change_24h_percent > 0
    assert analysis.vwap_24h_eth > 10.0
    assert analysis.moving_averages.sma_7 is not None
    assert analysis.moving_averages.sma_24 is not None
    assert analysis.trend_direction in (TrendDirection.BULLISH, TrendDirection.BREAKOUT)
    assert analysis.analyzed_sales_count == 5
