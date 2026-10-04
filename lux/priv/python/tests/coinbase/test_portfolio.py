"""
Unit tests for PortfolioTracker and Risk Management Engine.
"""

import pytest

from lux.coinbase.portfolio import PortfolioTracker
from lux.coinbase.types import OrderPlacementRequest, OrderSide, OrderType


def test_portfolio_initial_state():
    tracker = PortfolioTracker()
    assert tracker.get_total_balance_usd() == 0.0
    summary = tracker.get_summary()
    assert summary.total_balance_usd == 0.0
    assert len(summary.accounts) == 0


def test_balance_and_price_valuation():
    tracker = PortfolioTracker()

    # Add USD and BTC balances
    tracker.update_balance(currency="USD", available=10000.0)
    tracker.update_balance(currency="BTC", available=0.5)

    # Before BTC price is known
    assert tracker.get_asset_valuation_usd("USD") == 10000.0
    assert tracker.get_asset_valuation_usd("BTC") == 0.0

    # Set BTC price to $60,000
    tracker.update_price("BTC-USD", 60000.0)

    assert tracker.get_asset_valuation_usd("BTC") == 30000.0
    assert tracker.get_total_balance_usd() == 40000.0

    allocations = tracker.get_allocations()
    assert allocations["USD"] == 25.0
    assert allocations["BTC"] == 75.0


def test_trade_fill_and_pnl_tracking():
    tracker = PortfolioTracker()
    tracker.update_balance(currency="USD", available=50000.0)
    tracker.update_price("ETH-USD", 3000.0)

    # Buy 2 ETH @ $3,000 (total $6,000)
    tracker.record_fill(product_id="ETH-USD", side=OrderSide.BUY, size=2.0, price=3000.0, fee=10.0)

    pos_eth = tracker._positions["ETH"]
    assert pos_eth.available == 2.0
    assert pos_eth.cost_basis_usd == 3000.0
    assert tracker._positions["USD"].available == 43990.0  # 50000 - 6010

    # ETH price rises to $3,500 -> test unrealized PnL
    tracker.update_price("ETH-USD", 3500.0)
    pnl = tracker.calculate_pnl_24h()
    assert pnl["unrealized_pnl_usd"] == 1000.0  # (3500 - 3000) * 2

    # Sell 1 ETH @ $3,500 -> realize PnL
    tracker.record_fill(product_id="ETH-USD", side=OrderSide.SELL, size=1.0, price=3500.0, fee=5.0)
    assert pos_eth.available == 1.0
    assert pos_eth.realized_pnl_24h == 495.0  # (3500 - 3000) * 1 - 5 fee


def test_risk_limit_checks():
    tracker = PortfolioTracker(max_concentration_pct=30.0, max_position_usd=20000.0)
    tracker.update_balance(currency="USD", available=100000.0)
    tracker.update_price("SOL-USD", 100.0)

    # Valid order: Buy 50 SOL ($5,000 = 5% concentration, < 20k position)
    valid_order = OrderPlacementRequest(
        product_id="SOL-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        size=50.0,
        price=100.0,
    )
    res_valid = tracker.check_risk_limits(valid_order)
    assert res_valid["is_valid"] is True
    assert len(res_valid["violations"]) == 0

    # Invalid order: Buy 400 SOL ($40,000 = 40% concentration > 30% limit, > 20k position limit)
    oversized_order = OrderPlacementRequest(
        product_id="SOL-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        size=400.0,
        price=100.0,
    )
    res_invalid = tracker.check_risk_limits(oversized_order)
    assert res_invalid["is_valid"] is False
    assert len(res_invalid["violations"]) >= 1

    # Insufficient balance order
    excess_balance_order = OrderPlacementRequest(
        product_id="SOL-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        size=2000.0,
        price=100.0,
    )
    res_insufficient = tracker.check_risk_limits(excess_balance_order)
    assert res_insufficient["is_valid"] is False
    assert any("Insufficient USD" in v for v in res_insufficient["violations"])
