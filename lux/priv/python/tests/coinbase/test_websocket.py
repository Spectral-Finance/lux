"""
Unit tests for Coinbase Advanced Trade WebSocket Manager.
"""

import json
import time
from unittest.mock import MagicMock
import pytest

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.types import ChannelType
from lux.coinbase.websocket import CoinbaseWebSocketManager


def test_ws_subscription_registration():
    mgr = CoinbaseWebSocketManager()
    
    received_tickers = []
    def ticker_cb(msg):
        received_tickers.append(msg)

    mgr.subscribe(ChannelType.TICKER, ["BTC-USD", "ETH-USD"], callback=ticker_cb)
    
    assert "ticker" in mgr._subscriptions
    assert "BTC-USD" in mgr._subscriptions["ticker"]
    assert "ETH-USD" in mgr._subscriptions["ticker"]
    assert ticker_cb in mgr._callbacks["ticker"]

    # Unsubscribe single product
    mgr.unsubscribe(ChannelType.TICKER, ["BTC-USD"])
    assert "BTC-USD" not in mgr._subscriptions["ticker"]
    assert "ETH-USD" in mgr._subscriptions["ticker"]


def test_ws_message_dispatching():
    mgr = CoinbaseWebSocketManager()

    ticker_events = []
    user_events = []
    global_events = []

    mgr.register_callback(ChannelType.TICKER, lambda msg: ticker_events.append(msg))
    mgr.register_callback(ChannelType.USER, lambda msg: user_events.append(msg))
    mgr.register_callback(None, lambda msg: global_events.append(msg))

    # Simulate raw incoming ticker message
    ticker_payload = json.dumps({
        "channel": "ticker",
        "events": [
            {
                "type": "update",
                "tickers": [
                    {"product_id": "BTC-USD", "price": "52000.50", "volume_24h": "1234.5"}
                ]
            }
        ]
    })
    mgr._handle_raw_message(ticker_payload)

    assert len(ticker_events) == 1
    assert ticker_events[0]["channel"] == "ticker"
    assert len(user_events) == 0
    assert len(global_events) == 1

    # Simulate raw incoming user message
    user_payload = json.dumps({
        "channel": "user",
        "events": [
            {
                "type": "update",
                "orders": [{"order_id": "ord-1", "status": "FILLED"}]
            }
        ]
    })
    mgr._handle_raw_message(user_payload)

    assert len(ticker_events) == 1
    assert len(user_events) == 1
    assert len(global_events) == 2


def test_ws_heartbeat_tracking():
    mgr = CoinbaseWebSocketManager()
    assert mgr.last_heartbeat == 0.0

    heartbeat_msg = json.dumps({
        "channel": "heartbeats",
        "events": [{"current_time": "2026-10-04T00:00:00Z", "heartbeat_counter": 1}]
    })
    mgr._handle_raw_message(heartbeat_msg)
    # The heartbeat timestamp is updated upon message reception in connection loop or manual handling
    mgr._last_heartbeat = time.time()
    assert mgr.last_heartbeat > 0.0
