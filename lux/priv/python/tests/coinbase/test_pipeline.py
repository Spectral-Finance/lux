"""
Unit tests for Coinbase Pipeline orchestrator.
"""

from unittest.mock import MagicMock
import pytest

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.pipeline import CoinbasePipeline
from lux.coinbase.types import (
    AccountBalance,
    Candle,
    Granularity,
    Order,
    OrderPlacementRequest,
    OrderSide,
    OrderStatus,
    OrderType,
    Ticker,
)


@pytest.fixture
def mock_pipeline():
    auth = CoinbaseAuth(api_key="test_key", api_secret="test_secret")
    pipeline = CoinbasePipeline(
        auth=auth,
        max_concentration_pct=50.0,
        max_position_usd=50000.0,
    )
    # Mock REST client
    pipeline.rest = MagicMock()
    # Mock WS client
    pipeline.ws = MagicMock()
    return pipeline


def test_pipeline_sync_portfolio(mock_pipeline):
    mock_pipeline.rest.get_accounts.return_value = [
        AccountBalance(currency="USD", available=20000.0, hold=0.0, balance=20000.0),
        AccountBalance(currency="BTC", available=1.0, hold=0.0, balance=1.0),
    ]
    mock_pipeline.rest.get_best_bid_ask.return_value = [
        Ticker(product_id="BTC-USD", price=50000.0, best_bid=49990.0, best_ask=50010.0)
    ]

    summary = mock_pipeline.sync_portfolio()
    assert summary.total_balance_usd == 70000.0
    assert summary.allocations["USD"] == 28.57
    assert summary.allocations["BTC"] == 71.43


def test_pipeline_analyze_market(mock_pipeline):
    mock_pipeline.rest.get_candles.return_value = [
        Candle(start="1", low=100.0, high=110.0, open=102.0, close=105.0, volume=50.0),
        Candle(start="2", low=104.0, high=115.0, open=105.0, close=112.0, volume=70.0),
    ]

    analysis = mock_pipeline.analyze_market(product_id="ETH-USD", granularity=Granularity.ONE_HOUR)
    assert analysis["product_id"] == "ETH-USD"
    assert analysis["current_price"] == 112.0
    assert analysis["period_high"] == 115.0
    assert analysis["period_low"] == 100.0
    assert analysis["total_volume"] == 120.0
    assert analysis["candle_count"] == 2


def test_pipeline_safe_order_execution_approved(mock_pipeline):
    # Setup initial balances
    mock_pipeline.portfolio.update_balance("USD", available=100000.0)
    mock_pipeline.portfolio.update_price("BTC-USD", 50000.0)

    mock_pipeline.rest.create_order.return_value = Order(
        order_id="ord-999",
        product_id="BTC-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        price=50000.0,
        size=0.2,
        status=OrderStatus.OPEN,
    )

    req = OrderPlacementRequest(
        product_id="BTC-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        price=50000.0,
        size=0.2,
    )
    result = mock_pipeline.execute_order(req)
    assert result["status"] == "SUBMITTED"
    assert result["order_id"] == "ord-999"
    assert result["risk_evaluation"]["is_valid"] is True


def test_pipeline_safe_order_execution_rejected_by_risk(mock_pipeline):
    # Setup small balance
    mock_pipeline.portfolio.update_balance("USD", available=500.0)
    mock_pipeline.portfolio.update_price("BTC-USD", 50000.0)

    req = OrderPlacementRequest(
        product_id="BTC-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        price=50000.0,
        size=1.0,  # $50,000 order with only $500 USD available
    )
    result = mock_pipeline.execute_order(req)
    assert result["status"] == "REJECTED_BY_RISK_LIMITS"
    assert "Insufficient USD" in result["reason"]
    assert result["order"] is None


def test_pipeline_streaming_lifecycle(mock_pipeline):
    mock_pipeline.ws.start.return_value = True

    started = mock_pipeline.start_streaming(["BTC-USD", "ETH-USD"])
    assert started is True
    assert mock_pipeline.ws.start.called
    assert mock_pipeline.ws.subscribe.called

    mock_pipeline.stop_streaming()
    assert mock_pipeline.ws.stop.called
