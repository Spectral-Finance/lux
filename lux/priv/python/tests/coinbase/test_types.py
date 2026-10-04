"""
Unit tests for Coinbase types, models, serializers, and validations.
"""

import pytest

from lux.coinbase.types import (
    AccountBalance,
    Candle,
    CancelOrderResponse,
    ChannelType,
    Granularity,
    Order,
    OrderPlacementRequest,
    OrderSide,
    OrderStatus,
    OrderType,
    PortfolioSummary,
    Product,
    Ticker,
    TimeInForce,
)


def test_time_in_force_parsing():
    assert TimeInForce.from_str("GTC") == TimeInForce.GTC
    assert TimeInForce.from_str("GOOD_UNTIL_CANCELLED") == TimeInForce.GTC
    assert TimeInForce.from_str("IOC") == TimeInForce.IOC
    assert TimeInForce.from_str("IMMEDIATE_OR_CANCEL") == TimeInForce.IOC
    assert TimeInForce.from_str("FOK") == TimeInForce.FOK
    assert TimeInForce.from_str("GTD") == TimeInForce.GTD
    assert TimeInForce.from_str("unknown") == TimeInForce.GTC


def test_granularity_seconds_and_parsing():
    assert Granularity.ONE_MINUTE.seconds == 60
    assert Granularity.FIVE_MINUTE.seconds == 300
    assert Granularity.FIFTEEN_MINUTE.seconds == 900
    assert Granularity.ONE_HOUR.seconds == 3600
    assert Granularity.SIX_HOUR.seconds == 21600
    assert Granularity.ONE_DAY.seconds == 86400

    assert Granularity.from_seconds(60) == Granularity.ONE_MINUTE
    assert Granularity.from_seconds(3600) == Granularity.ONE_HOUR

    with pytest.raises(ValueError):
        Granularity.from_seconds(9999)


def test_product_model_validation():
    data = {
        "product_id": "BTC-USD",
        "base_currency_id": "BTC",
        "quote_currency_id": "USD",
        "quote_increment": "0.01",
        "base_increment": "0.00000001",
        "status": "online",
        "display_name": "Bitcoin / USD",
    }
    prod = Product.model_validate(data)
    assert prod.id == "BTC-USD"
    assert prod.base_currency == "BTC"
    assert prod.quote_currency == "USD"
    assert prod.quote_increment == 0.01
    assert prod.base_increment == 1e-8


def test_order_placement_payload_market_buy_quote_size():
    req = OrderPlacementRequest(
        product_id="BTC-USD",
        side=OrderSide.BUY,
        order_type=OrderType.MARKET,
        quote_size=500.0,
        client_order_id="mkt-buy-1",
    )
    payload = req.to_coinbase_payload()
    assert payload["product_id"] == "BTC-USD"
    assert payload["side"] == "BUY"
    assert payload["client_order_id"] == "mkt-buy-1"
    assert "market_market_ioc" in payload["order_configuration"]
    assert payload["order_configuration"]["market_market_ioc"]["quote_size"] == "500.0"


def test_order_placement_payload_stop_limit():
    req = OrderPlacementRequest(
        product_id="ETH-USD",
        side=OrderSide.SELL,
        order_type=OrderType.STOP_LIMIT,
        size=1.5,
        price=2900.0,
        stop_price=2950.0,
    )
    payload = req.to_coinbase_payload()
    assert payload["side"] == "SELL"
    assert "stop_limit_stop_limit_gtc" in payload["order_configuration"]
    cfg = payload["order_configuration"]["stop_limit_stop_limit_gtc"]
    assert cfg["limit_price"] == "2900.0"
    assert cfg["stop_price"] == "2950.0"
    assert cfg["stop_direction"] == "STOP_DIRECTION_STOP_DOWN"


def test_portfolio_summary_model():
    summary = PortfolioSummary(
        total_balance_usd=125000.50,
        accounts=[
            AccountBalance(currency="USD", available=25000.50, hold=0.0, balance=25000.50),
            AccountBalance(currency="BTC", available=1.5, hold=0.1, balance=1.6),
        ],
        allocations={"USD": 20.0, "BTC": 80.0},
        unrealized_pnl=5200.0,
        realized_pnl_24h=350.0,
    )
    assert summary.total_balance_usd == 125000.50
    assert len(summary.accounts) == 2
    assert summary.allocations["BTC"] == 80.0
