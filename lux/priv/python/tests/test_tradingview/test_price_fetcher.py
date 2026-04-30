"""Unit tests for TradingView Price Fetcher."""

import pytest
import json
from unittest.mock import patch, MagicMock
from tradingview.price_fetcher import PriceFetcher


class TestPriceFetcher:
    """Tests for price data fetching."""

    def setup_method(self):
        self.fetcher = PriceFetcher()

    def test_get_klines_structure(self):
        """Test kline data has correct structure."""
        mock_response = [
            [1700000000000, "50000.00", "50100.00", "49900.00", "50050.00", "100.5"],
            [1700003600000, "50050.00", "50200.00", "50000.00", "50150.00", "120.3"],
        ]

        with patch.object(self.fetcher, '_fetch_url', return_value=json.dumps(mock_response)):
            result = self.fetcher.get_klines("BTCUSDT", "1h", 2)

        assert len(result) == 2
        assert "open" in result[0]
        assert "high" in result[0]
        assert "low" in result[0]
        assert "close" in result[0]
        assert "volume" in result[0]
        assert result[0]["open"] == 50000.00
        assert result[0]["high"] == 50100.00
        assert result[0]["low"] == 49900.00
        assert result[0]["close"] == 50050.00
        assert result[0]["volume"] == 100.5

    def test_get_klines_empty_on_error(self):
        """Test kline fetch returns empty list on error."""
        with patch.object(self.fetcher, '_fetch_url', return_value=None):
            result = self.fetcher.get_klines("INVALID", "1h", 10)

        assert result == []

    def test_get_klines_empty_on_invalid_response(self):
        """Test kline fetch returns empty list on invalid response."""
        with patch.object(self.fetcher, '_fetch_url', return_value="not json"):
            result = self.fetcher.get_klines("BTCUSDT", "1h", 10)

        assert result == []

    def test_get_ticker_price(self):
        """Test ticker price fetch."""
        mock_response = json.dumps({"symbol": "BTCUSDT", "price": "67500.00"})

        with patch.object(self.fetcher, '_fetch_url', return_value=mock_response):
            result = self.fetcher.get_ticker_price("BTCUSDT")

        assert result is not None
        assert result["symbol"] == "BTCUSDT"
        assert result["price"] == 67500.00

    def test_get_ticker_price_error(self):
        """Test ticker price returns None on error."""
        with patch.object(self.fetcher, '_fetch_url', return_value=None):
            result = self.fetcher.get_ticker_price("INVALID")

        assert result is None

    def test_get_24h_ticker(self):
        """Test 24h ticker fetch."""
        mock_response = json.dumps({
            "symbol": "BTCUSDT",
            "lastPrice": "67500.00",
            "highPrice": "68000.00",
            "lowPrice": "66000.00",
            "volume": "15000.00",
            "quoteVolume": "1000000000.00",
            "priceChange": "1500.00",
            "priceChangePercent": "2.27"
        })

        with patch.object(self.fetcher, '_fetch_url', return_value=mock_response):
            result = self.fetcher.get_24h_ticker("BTCUSDT")

        assert result is not None
        assert result["symbol"] == "BTCUSDT"
        assert result["last_price"] == 67500.00
        assert result["high_price"] == 68000.00
        assert result["low_price"] == 66000.00
        assert result["volume"] == 15000.00
        assert result["price_change_percent"] == 2.27

    def test_parse_klines(self):
        """Test kline parsing."""
        raw = [
            [1700000000000, "50000.00", "50100.00", "49900.00", "50050.00", "100.5", 1700003599999],
        ]

        result = self.fetcher._parse_klines(raw)

        assert len(result) == 1
        assert result[0]["open_time"] == 1700000000000
        assert result[0]["close_time"] == 1700003599999

    def test_parse_klines_skips_invalid(self):
        """Test that invalid klines are skipped."""
        raw = [
            [1700000000000, "50000.00"],  # Too few fields
            [1700000000000, "50000.00", "50100.00", "49900.00", "50050.00", "100.5"],  # Valid
        ]

        result = self.fetcher._parse_klines(raw)

        assert len(result) == 1

    def test_fetch_url_timeout(self):
        """Test URL fetch handles timeout gracefully."""
        import urllib.error

        with patch('urllib.request.urlopen', side_effect=Exception("Timeout")):
            result = self.fetcher._fetch_url("https://example.com")

        assert result is None

    def test_limit_capped_at_1000(self):
        """Test that limit is capped at 1000."""
        mock_response = json.dumps([])

        with patch.object(self.fetcher, '_fetch_url', return_value=mock_response) as mock_fetch:
            self.fetcher.get_klines("BTCUSDT", "1h", 5000)

            # Check that URL contains limit=1000
            call_args = mock_fetch.call_args[0][0]
            assert "limit=1000" in call_args
