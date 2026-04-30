"""Price Data Fetcher.

Fetches cryptocurrency price data from the Binance public API.
No API key required for market data endpoints.

## Usage

    from tradingview.price_fetcher import PriceFetcher
    fetcher = PriceFetcher()
    klines = fetcher.get_klines("BTCUSDT", "1h", 100)
"""

import json
import urllib.request
import urllib.error
from typing import List, Dict, Optional, Any


class PriceFetcher:
    """Fetches price data from Binance public API.

    All methods use the Binance public API which requires no authentication.
    Data is returned in a standardized format compatible with the Lux framework.
    """

    BASE_URL = "https://api.binance.com/api/v3"

    def get_klines(
        self, symbol: str, interval: str = "1h", limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Fetch kline (candlestick) data from Binance.

        Args:
            symbol: Trading pair symbol (e.g., 'BTCUSDT', 'ETHUSDT')
            interval: Kline interval ('1m', '5m', '15m', '30m', '1h', '4h', '1d', '1w')
            limit: Number of candles to fetch (default 100, max 1000)

        Returns:
            List of dicts with keys: open_time, open, high, low, close, volume, close_time

        Raises:
            Exception: If the API request fails
        """
        url = f"{self.BASE_URL}/klines?symbol={symbol}&interval={interval}&limit={min(limit, 1000)}"

        try:
            response = self._fetch_url(url)
            if response is None:
                return []

            klines = json.loads(response)
            if not isinstance(klines, list):
                return []

            return self._parse_klines(klines)

        except Exception as e:
            # Return empty list on error to allow graceful degradation
            return []

    def get_ticker_price(self, symbol: str) -> Optional[Dict[str, Any]]:
        """Fetch current price for a symbol.

        Args:
            symbol: Trading pair symbol (e.g., 'BTCUSDT')

        Returns:
            Dict with 'symbol' and 'price' keys, or None on error
        """
        url = f"{self.BASE_URL}/ticker/price?symbol={symbol}"

        try:
            response = self._fetch_url(url)
            if response is None:
                return None

            data = json.loads(response)
            return {
                "symbol": data.get("symbol", symbol),
                "price": float(data.get("price", 0)),
            }
        except Exception:
            return None

    def get_24h_ticker(self, symbol: str) -> Optional[Dict[str, Any]]:
        """Fetch 24-hour ticker statistics.

        Args:
            symbol: Trading pair symbol (e.g., 'BTCUSDT')

        Returns:
            Dict with 24h statistics, or None on error
        """
        url = f"{self.BASE_URL}/ticker/24hr?symbol={symbol}"

        try:
            response = self._fetch_url(url)
            if response is None:
                return None

            data = json.loads(response)
            return {
                "symbol": data.get("symbol", symbol),
                "last_price": float(data.get("lastPrice", 0)),
                "high_price": float(data.get("highPrice", 0)),
                "low_price": float(data.get("lowPrice", 0)),
                "volume": float(data.get("volume", 0)),
                "quote_volume": float(data.get("quoteVolume", 0)),
                "price_change": float(data.get("priceChange", 0)),
                "price_change_percent": float(data.get("priceChangePercent", 0)),
            }
        except Exception:
            return None

    def _fetch_url(self, url: str, timeout: int = 10) -> Optional[str]:
        """Fetch URL content and return as string.

        Args:
            url: URL to fetch
            timeout: Request timeout in seconds

        Returns:
            Response body as string, or None on error
        """
        try:
            request = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "SpectralFinance-Lux/1.0",
                    "Accept": "application/json",
                },
            )
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read().decode("utf-8")
        except (urllib.error.URLError, urllib.error.HTTPError, Exception):
            return None

    def _parse_klines(self, raw_klines: list) -> List[Dict[str, Any]]:
        """Parse raw Binance kline data into standardized format.

        Binance kline format:
        [open_time, open, high, low, close, volume, close_time, ...]

        Args:
            raw_klines: Raw kline data from Binance API

        Returns:
            List of standardized kline dicts with numeric values
        """
        parsed = []
        for kline in raw_klines:
            if len(kline) < 6:
                continue

            parsed.append(
                {
                    "open_time": kline[0],
                    "open": float(kline[1]),
                    "high": float(kline[2]),
                    "low": float(kline[3]),
                    "close": float(kline[4]),
                    "volume": float(kline[5]),
                    "close_time": kline[6] if len(kline) > 6 else None,
                }
            )

        return parsed
