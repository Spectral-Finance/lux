"""
Tests for Coinbase utilities.
"""

import pytest
import base64
import hmac
import hashlib
import time
from coinbase_utils.setup import CoinbaseAuth, CoinbaseRestClient, CoinbaseWebSocket


class TestCoinbaseAuth:
    """Tests for Coinbase authentication."""

    def test_signature_generation(self):
        """Test that signature is generated correctly."""
        api_key = "test_key"
        api_secret = base64.b64encode(b"test_secret").decode('utf-8')
        passphrase = "test_passphrase"

        auth = CoinbaseAuth(api_key, api_secret, passphrase)
        signature = auth.generate_signature("GET", "/accounts")

        assert signature is not None
        assert len(signature) > 0

    def test_headers_generation(self):
        """Test that headers are generated correctly."""
        api_key = "test_key"
        api_secret = base64.b64encode(b"test_secret").decode('utf-8')
        passphrase = "test_passphrase"

        auth = CoinbaseAuth(api_key, api_secret, passphrase)
        headers = auth.get_headers("GET", "/accounts")

        assert headers['CB-ACCESS-KEY'] == api_key
        assert headers['CB-ACCESS-PASSPHRASE'] == passphrase
        assert 'CB-ACCESS-SIGN' in headers
        assert 'CB-ACCESS-TIMESTAMP' in headers
        assert headers['Content-Type'] == 'application/json'


class TestCoinbaseRestClient:
    """Tests for Coinbase REST client."""

    def test_client_initialization(self):
        """Test client initializes correctly."""
        client = CoinbaseRestClient("key", base64.b64encode(b"secret").decode(), "pass")

        assert client.base_url == "https://api.exchange.coinbase.com"

    def test_custom_base_url(self):
        """Test custom base URL."""
        custom_url = "https://api-public.sandbox.exchange.coinbase.com"
        client = CoinbaseRestClient("key", base64.b64encode(b"secret").decode(), "pass", custom_url)

        assert client.base_url == custom_url


class TestCoinbaseWebSocket:
    """Tests for Coinbase WebSocket client."""

    def test_websocket_initialization(self):
        """Test WebSocket client initializes correctly."""
        ws = CoinbaseWebSocket("key", base64.b64encode(b"secret").decode(), "pass")

        assert ws.ws_url == "wss://ws-feed.exchange.coinbase.com"

    def test_custom_ws_url(self):
        """Test custom WebSocket URL."""
        custom_url = "wss://ws-feed-public.sandbox.exchange.coinbase.com"
        ws = CoinbaseWebSocket("key", base64.b64encode(b"secret").decode(), "pass", custom_url)

        assert ws.ws_url == custom_url

    def test_subscribe_message_public(self):
        """Test public subscribe message generation."""
        ws = CoinbaseWebSocket("key", base64.b64encode(b"secret").decode(), "pass")
        message = ws._get_subscribe_message("ticker", ["BTC-USD"], auth=False)

        assert message["type"] == "subscribe"
        assert message["channel"] == "ticker"
        assert "BTC-USD" in message["product_ids"]

    def test_subscribe_message_authenticated(self):
        """Test authenticated subscribe message generation."""
        api_key = "test_key"
        api_secret = base64.b64encode(b"test_secret").decode('utf-8')
        passphrase = "test_pass"

        ws = CoinbaseWebSocket(api_key, api_secret, passphrase)
        message = ws._get_subscribe_message("user", ["BTC-USD"], auth=True)

        assert message["type"] == "subscribe"
        assert message["channel"] == "user"
        assert message["key"] == api_key
        assert message["passphrase"] == passphrase
        assert "signature" in message
        assert "timestamp" in message


class TestSetup:
    """Tests for setup function."""

    def test_setup_returns_clients(self):
        """Test setup returns both clients."""
        api_key = "test_key"
        api_secret = base64.b64encode(b"test_secret").decode('utf-8')
        passphrase = "test_passphrase"

        rest_client, ws_client = setup(api_key, api_secret, passphrase)

        assert rest_client is not None
        assert ws_client is not None
        assert isinstance(rest_client, CoinbaseRestClient)
        assert isinstance(ws_client, CoinbaseWebSocket)