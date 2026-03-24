"""
Coinbase Exchange API utilities for authentication and client setup.
"""

import base64
import hashlib
import hmac
import time
from typing import Optional, Dict, Any
import requests
import websocket
import json


class CoinbaseAuth:
    """Handles Coinbase Exchange API authentication."""
    
    def __init__(self, api_key: str, api_secret: str, passphrase: str):
        self.api_key = api_key
        self.api_secret = api_secret
        self.passphrase = passphrase
    
    def generate_signature(self, method: str, path: str, body: str = "") -> str:
        """Generate HMAC-SHA256 signature for API request."""
        timestamp = str(time.time())
        message = timestamp + method + path + body
        
        signature = hmac.new(
            base64.b64decode(self.api_secret),
            message.encode('utf-8'),
            hashlib.sha256
        )
        
        return base64.b64encode(signature.digest()).decode('utf-8')
    
    def get_headers(self, method: str, path: str, body: str = "") -> Dict[str, str]:
        """Get authenticated headers for API request."""
        timestamp = str(time.time())
        signature = self.generate_signature(method, path, body)
        
        return {
            'CB-ACCESS-KEY': self.api_key,
            'CB-ACCESS-SIGN': signature,
            'CB-ACCESS-TIMESTAMP': timestamp,
            'CB-ACCESS-PASSPHRASE': self.passphrase,
            'Content-Type': 'application/json'
        }


class CoinbaseRestClient:
    """REST API client for Coinbase Exchange."""
    
    BASE_URL = "https://api.exchange.coinbase.com"
    
    def __init__(self, api_key: str, api_secret: str, passphrase: str, base_url: Optional[str] = None):
        self.auth = CoinbaseAuth(api_key, api_secret, passphrase)
        self.base_url = base_url or self.BASE_URL
    
    def _request(self, method: str, path: str, body: Optional[Dict] = None) -> Dict[str, Any]:
        """Make authenticated API request."""
        body_str = json.dumps(body) if body else ""
        headers = self.auth.get_headers(method, path, body_str)
        url = self.base_url + path
        
        response = requests.request(
            method=method,
            url=url,
            headers=headers,
            data=body_str if body else None
        )
        
        if response.status_code >= 400:
            raise Exception(f"API error: {response.status_code} - {response.text}")
        
        return response.json()
    
    # Account endpoints
    def get_accounts(self) -> list:
        """Get all accounts."""
        return self._request("GET", "/accounts")
    
    def get_account(self, account_id: str) -> dict:
        """Get a specific account."""
        return self._request("GET", f"/accounts/{account_id}")
    
    def get_account_holds(self, account_id: str) -> list:
        """Get account holds."""
        return self._request("GET", f"/accounts/{account_id}/holds")
    
    # Order endpoints
    def place_order(self, order: Dict[str, Any]) -> dict:
        """Place a new order."""
        return self._request("POST", "/orders", order)
    
    def cancel_order(self, order_id: str) -> list:
        """Cancel an order."""
        return self._request("DELETE", f"/orders/{order_id}")
    
    def cancel_all_orders(self, product_id: Optional[str] = None) -> list:
        """Cancel all orders, optionally filtered by product."""
        path = "/orders"
        if product_id:
            path += f"?product_id={product_id}"
        return self._request("DELETE", path)
    
    def get_orders(self, product_id: Optional[str] = None, status: Optional[str] = None) -> list:
        """Get orders with optional filters."""
        params = []
        if product_id:
            params.append(f"product_id={product_id}")
        if status:
            params.append(f"status={status}")
        path = "/orders"
        if params:
            path += "?" + "&".join(params)
        return self._request("GET", path)
    
    def get_order(self, order_id: str) -> dict:
        """Get a specific order."""
        return self._request("GET", f"/orders/{order_id}")
    
    # Market data endpoints
    def get_products(self) -> list:
        """Get all trading products."""
        return self._request("GET", "/products")
    
    def get_product(self, product_id: str) -> dict:
        """Get a specific product."""
        return self._request("GET", f"/products/{product_id}")
    
    def get_product_ticker(self, product_id: str) -> dict:
        """Get product ticker."""
        return self._request("GET", f"/products/{product_id}/ticker")
    
    def get_product_order_book(self, product_id: str, level: int = 1) -> dict:
        """Get product order book."""
        return self._request("GET", f"/products/{product_id}/book?level={level}")
    
    def get_product_trades(self, product_id: str) -> list:
        """Get recent trades for a product."""
        return self._request("GET", f"/products/{product_id}/trades")
    
    def get_candles(self, product_id: str, granularity: int = 86400) -> list:
        """Get historical candle data."""
        return self._request("GET", f"/products/{product_id}/candles?granularity={granularity}")
    
    # Fee endpoints
    def get_fees(self) -> dict:
        """Get current fee rates."""
        return self._request("GET", "/fees")


class CoinbaseWebSocket:
    """WebSocket client for Coinbase Exchange real-time data."""
    
    WS_URL = "wss://ws-feed.exchange.coinbase.com"
    
    def __init__(self, api_key: str, api_secret: str, passphrase: str, ws_url: Optional[str] = None):
        self.api_key = api_key
        self.api_secret = api_secret
        self.passphrase = passphrase
        self.ws_url = ws_url or self.WS_URL
        self.ws = None
        self.subscriptions = []
    
    def _get_signature(self, channel: str, product_ids: list) -> str:
        """Generate signature for WebSocket authentication."""
        timestamp = str(int(time.time()))
        message = timestamp + channel + ",".join(product_ids)
        
        signature = hmac.new(
            base64.b64decode(self.api_secret),
            message.encode('utf-8'),
            hashlib.sha256
        )
        
        return base64.b64encode(signature.digest()).decode('utf-8')
    
    def _get_subscribe_message(self, channel: str, product_ids: list, auth: bool = True) -> dict:
        """Create subscription message."""
        message = {
            "type": "subscribe",
            "channel": channel,
            "product_ids": product_ids
        }
        
        if auth:
            timestamp = str(int(time.time()))
            signature = self._get_signature(channel, product_ids)
            message["signature"] = signature
            message["key"] = self.api_key
            message["passphrase"] = self.passphrase
            message["timestamp"] = timestamp
        
        return message
    
    def subscribe(self, channel: str, product_ids: list, callback=None):
        """Subscribe to a channel."""
        message = self._get_subscribe_message(channel, product_ids, auth=True)
        self.subscriptions.append({
            "message": message,
            "callback": callback
        })
    
    def connect(self, on_message=None, on_error=None, on_close=None, on_open=None):
        """Connect to WebSocket."""
        def on_ws_message(ws, message):
            data = json.loads(message)
            if on_message:
                on_message(data)
            else:
                print(f"Received: {data}")
        
        def on_ws_error(ws, error):
            if on_error:
                on_error(error)
            else:
                print(f"Error: {error}")
        
        def on_ws_close(ws, close_status_code, close_msg):
            if on_close:
                on_close(close_status_code, close_msg)
            else:
                print("Connection closed")
        
        def on_ws_open(ws):
            # Send all pending subscriptions
            for sub in self.subscriptions:
                ws.send(json.dumps(sub["message"]))
            if on_open:
                on_open()
        
        self.ws = websocket.WebSocketApp(
            self.ws_url,
            on_message=on_ws_message,
            on_error=on_ws_error,
            on_close=on_ws_close,
            on_open=on_ws_open
        )
    
    def run_forever(self):
        """Run WebSocket connection forever."""
        if self.ws:
            self.ws.run_forever()
    
    def close(self):
        """Close WebSocket connection."""
        if self.ws:
            self.ws.close()


def setup(api_key: str, api_secret: str, passphrase: str, base_url: Optional[str] = None):
    """
    Setup Coinbase Exchange client.
    
    Args:
        api_key: Coinbase API key
        api_secret: Coinbase API secret (base64 encoded)
        passphrase: Coinbase API passphrase
        base_url: Optional custom base URL
    
    Returns:
        Tuple of (rest_client, websocket_client)
    """
    rest_client = CoinbaseRestClient(api_key, api_secret, passphrase, base_url)
    ws_client = CoinbaseWebSocket(api_key, api_secret, passphrase)
    return rest_client, ws_client