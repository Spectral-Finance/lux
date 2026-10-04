"""
Unit tests for Coinbase Advanced Trade REST Client with mocked HTTP interactions.
"""

from unittest.mock import MagicMock, patch
import pytest
import requests

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.rest import (
    CoinbaseAPIError,
    CoinbaseAuthError,
    CoinbaseNotFoundError,
    CoinbaseRateLimitError,
    CoinbaseRestClient,
)
from lux.coinbase.types import (
    Granularity,
    OrderPlacementRequest,
    OrderSide,
    OrderStatus,
    OrderType,
)


@pytest.fixture
def mock_session():
    return MagicMock(spec=requests.Session)


@pytest.fixture
def client(mock_session):
    auth = CoinbaseAuth(api_key="test_key", api_secret="test_secret")
    return CoinbaseRestClient(auth=auth, session=mock_session)


def test_get_products(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"products": [{"product_id": "BTC-USD", "base_currency_id": "BTC", "quote_currency_id": "USD", "quote_increment": "0.01", "base_increment": "0.00000001", "status": "online"}]}'
    mock_resp.json.return_value = {
        "products": [
            {
                "product_id": "BTC-USD",
                "base_currency_id": "BTC",
                "quote_currency_id": "USD",
                "quote_increment": "0.01",
                "base_increment": "0.00000001",
                "status": "online",
            }
        ]
    }
    mock_session.request.return_value = mock_resp

    products = client.get_products()
    assert len(products) == 1
    assert products[0].id == "BTC-USD"
    assert products[0].base_currency == "BTC"
    assert products[0].quote_currency == "USD"
    assert products[0].status == "online"


def test_get_product(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"product_id": "ETH-USD", "base_currency_id": "ETH", "quote_currency_id": "USD", "status": "online"}'
    mock_resp.json.return_value = {
        "product_id": "ETH-USD",
        "base_currency_id": "ETH",
        "quote_currency_id": "USD",
        "status": "online",
    }
    mock_session.request.return_value = mock_resp

    prod = client.get_product("ETH-USD")
    assert prod.id == "ETH-USD"
    assert prod.base_currency == "ETH"


def test_get_candles(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"candles": [{"start": "1630000000", "low": "45000", "high": "46000", "open": "45500", "close": "45800", "volume": "10.5"}]}'
    mock_resp.json.return_value = {
        "candles": [
            {
                "start": "1630000000",
                "low": "45000",
                "high": "46000",
                "open": "45500",
                "close": "45800",
                "volume": "10.5",
            }
        ]
    }
    mock_session.request.return_value = mock_resp

    candles = client.get_candles("BTC-USD", Granularity.ONE_HOUR)
    assert len(candles) == 1
    assert candles[0].close == 45800.0
    assert candles[0].volume == 10.5


def test_get_best_bid_ask(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"pricebooks": [{"product_id": "BTC-USD", "bids": [{"price": "50000", "size": "1"}], "asks": [{"price": "50010", "size": "1"}], "time": "2026-10-04T00:00:00Z"}]}'
    mock_resp.json.return_value = {
        "pricebooks": [
            {
                "product_id": "BTC-USD",
                "bids": [{"price": "50000", "size": "1"}],
                "asks": [{"price": "50010", "size": "1"}],
                "time": "2026-10-04T00:00:00Z",
            }
        ]
    }
    mock_session.request.return_value = mock_resp

    tickers = client.get_best_bid_ask(["BTC-USD"])
    assert len(tickers) == 1
    assert tickers[0].product_id == "BTC-USD"
    assert tickers[0].best_bid == 50000.0
    assert tickers[0].best_ask == 50010.0
    assert tickers[0].price == 50005.0


def test_get_accounts(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"accounts": [{"currency": "USD", "available_balance": {"value": "5000.0"}, "hold": {"value": "0.0"}, "uuid": "acc-1"}]}'
    mock_resp.json.return_value = {
        "accounts": [
            {
                "currency": "USD",
                "available_balance": {"value": "5000.0"},
                "hold": {"value": "0.0"},
                "uuid": "acc-1",
            }
        ]
    }
    mock_session.request.return_value = mock_resp

    accounts = client.get_accounts()
    assert len(accounts) == 1
    assert accounts[0].currency == "USD"
    assert accounts[0].available == 5000.0
    assert accounts[0].balance == 5000.0


def test_create_order(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"success_response": {"order_id": "ord-123", "product_id": "BTC-USD", "side": "BUY", "client_order_id": "c1"}}'
    mock_resp.json.return_value = {
        "success_response": {
            "order_id": "ord-123",
            "product_id": "BTC-USD",
            "side": "BUY",
            "client_order_id": "c1",
        }
    }
    mock_session.request.return_value = mock_resp

    req = OrderPlacementRequest(
        product_id="BTC-USD",
        side=OrderSide.BUY,
        order_type=OrderType.LIMIT,
        size=0.1,
        price=50000.0,
        client_order_id="c1",
    )
    order = client.create_order(req)
    assert order.order_id == "ord-123"
    assert order.product_id == "BTC-USD"
    assert order.side == OrderSide.BUY
    assert order.status == OrderStatus.OPEN


def test_cancel_orders(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"results": [{"success": true, "order_id": "ord-123"}]}'
    mock_resp.json.return_value = {
        "results": [{"success": True, "order_id": "ord-123"}]
    }
    mock_session.request.return_value = mock_resp

    res = client.cancel_orders(["ord-123"])
    assert len(res) == 1
    assert res[0].success is True
    assert res[0].order_id == "ord-123"


def test_get_single_account(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"account": {"currency": "ETH", "available_balance": {"value": "10.0"}, "hold": {"value": "1.0"}, "uuid": "eth-acc-1"}}'
    mock_resp.json.return_value = {
        "account": {
            "currency": "ETH",
            "available_balance": {"value": "10.0"},
            "hold": {"value": "1.0"},
            "uuid": "eth-acc-1",
        }
    }
    mock_session.request.return_value = mock_resp

    account = client.get_account("eth-acc-1")
    assert account.currency == "ETH"
    assert account.available == 10.0
    assert account.hold == 1.0
    assert account.balance == 11.0


def test_get_portfolio_breakdown(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"breakdown": {"portfolio_balances": {"total_balance": {"value": "10000.0"}, "unrealized_pnl": {"value": "500.0"}}, "spot_positions": [{"asset": "BTC", "total_balance_fiat": 8000.0, "total_balance_crypto": 0.16, "hold_crypto": 0.0}]}}'
    mock_resp.json.return_value = {
        "breakdown": {
            "portfolio_balances": {
                "total_balance": {"value": "10000.0"},
                "unrealized_pnl": {"value": "500.0"},
            },
            "spot_positions": [
                {
                    "asset": "BTC",
                    "total_balance_fiat": 8000.0,
                    "total_balance_crypto": 0.16,
                    "hold_crypto": 0.0,
                }
            ],
        }
    }
    mock_session.request.return_value = mock_resp

    summary = client.get_portfolio_breakdown()
    assert summary.total_balance_usd == 10000.0
    assert summary.unrealized_pnl == 500.0
    assert summary.allocations["BTC"] == 80.0


def test_get_transaction_summary(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"fee_tier": {"pricing_tier": "Tier 1", "taker_fee_rate": "0.006", "maker_fee_rate": "0.004"}}'
    mock_resp.json.return_value = {
        "fee_tier": {
            "pricing_tier": "Tier 1",
            "taker_fee_rate": "0.006",
            "maker_fee_rate": "0.004",
        }
    }
    mock_session.request.return_value = mock_resp

    summary = client.get_transaction_summary()
    assert "fee_tier" in summary
    assert summary["fee_tier"]["pricing_tier"] == "Tier 1"


def test_get_order(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"order": {"order_id": "ord-777", "product_id": "BTC-USD", "side": "BUY", "order_type": "LIMIT", "status": "FILLED", "filled_size": "0.5", "filled_value": "25000"}}'
    mock_resp.json.return_value = {
        "order": {
            "order_id": "ord-777",
            "product_id": "BTC-USD",
            "side": "BUY",
            "order_type": "LIMIT",
            "status": "FILLED",
            "filled_size": "0.5",
            "filled_value": "25000",
        }
    }
    mock_session.request.return_value = mock_resp

    order = client.get_order("ord-777")
    assert order.order_id == "ord-777"
    assert order.status == OrderStatus.FILLED
    assert order.filled_size == 0.5


def test_list_orders(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.content = b'{"orders": [{"order_id": "ord-1", "product_id": "BTC-USD", "side": "BUY", "order_type": "MARKET", "status": "OPEN"}]}'
    mock_resp.json.return_value = {
        "orders": [
            {
                "order_id": "ord-1",
                "product_id": "BTC-USD",
                "side": "BUY",
                "order_type": "MARKET",
                "status": "OPEN",
            }
        ]
    }
    mock_session.request.return_value = mock_resp

    orders = client.list_orders(product_id="BTC-USD", order_status=OrderStatus.OPEN)
    assert len(orders) == 1
    assert orders[0].order_id == "ord-1"


def test_error_handling_401(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 401
    mock_resp.text = '{"error": "Unauthorized"}'
    mock_session.request.return_value = mock_resp

    with pytest.raises(CoinbaseAuthError):
        client.get_accounts()


def test_error_handling_404(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 404
    mock_resp.text = '{"error": "Not found"}'
    mock_session.request.return_value = mock_resp

    with pytest.raises(CoinbaseNotFoundError):
        client.get_product("UNKNOWN-PAIR")


def test_error_handling_429(client, mock_session):
    mock_resp = MagicMock()
    mock_resp.status_code = 429
    mock_resp.headers = {"Retry-After": "0.01"}
    mock_resp.text = '{"error": "Rate limited"}'
    mock_session.request.return_value = mock_resp

    with pytest.raises(CoinbaseRateLimitError):
        client.get_accounts()
