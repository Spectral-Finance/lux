import pytest
from unittest.mock import MagicMock
from hyperliquid_utils import trading

def test_place_order_success():
    mock_exchange = MagicMock()
    mock_exchange.order.return_value = {"status": "success", "order_id": 123}
    
    result = trading.place_order(mock_exchange, "ETH", True, 0.1, 2500)
    
    assert result["status"] == "success"
    assert "order_id" in result["data"]
    mock_exchange.order.assert_called_once()

def test_place_order_invalid_size():
    mock_exchange = MagicMock()
    
    result = trading.place_order(mock_exchange, "ETH", True, -0.1, 2500)
    
    assert result["status"] == "error"
    assert "must be positive" in result["message"]

def test_get_positions_success():
    mock_info = MagicMock()
    mock_info.user_state.return_value = {
        "positions": [{
            "position": {"szi": "0.5", "dir": "LONG", "entryPx": "2400"},
            "markPx": "2500",
            "marginSummary": {"accountValue": "5000"}
        }]
    }
    
    result = trading.get_positions(mock_info, "0x123")
    
    assert result["status"] == "success"
    assert result["metadata"]["count"] == 1
    assert result["data"][0]["unrealized_pnl"] == 50  # (2500-2400)*0.5

def test_set_leverage_valid():
    mock_exchange = MagicMock()
    mock_exchange.update_leverage.return_value = {"status": "ok"}
    
    result = trading.set_leverage(mock_exchange, 10, "BTC")
    
    assert result["status"] == "success"
    assert result["metadata"]["leverage"] == 10
    assert result["metadata"]["symbol"] == "BTC"
    mock_exchange.update_leverage.assert_called_once_with(10, "BTC")

def test_set_leverage_invalid():
    mock_exchange = MagicMock()
    
    result = trading.set_leverage(mock_exchange, 150)
    
    assert result["status"] == "error"
    assert "1-100" in result["message"]
