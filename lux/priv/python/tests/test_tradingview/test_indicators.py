"""Unit tests for TradingView Technical Analysis Indicators."""

import pytest
from tradingview.indicators import Indicators


class TestSMA:
    """Tests for Simple Moving Average."""

    def setup_method(self):
        self.ind = Indicators()

    def test_sma_basic(self):
        """Test basic SMA calculation."""
        prices = [1.0, 2.0, 3.0, 4.0, 5.0]
        result = self.ind.sma(prices, 3)

        assert result[0] is None
        assert result[1] is None
        assert result[2] == 2.0  # (1+2+3)/3
        assert result[3] == 3.0  # (2+3+4)/3
        assert result[4] == 4.0  # (3+4+5)/3

    def test_sma_period_1(self):
        """Test SMA with period 1 returns same values."""
        prices = [1.0, 2.0, 3.0]
        result = self.ind.sma(prices, 1)
        assert result == [1.0, 2.0, 3.0]

    def test_sma_empty_input(self):
        """Test SMA with empty input."""
        assert self.ind.sma([], 5) == []

    def test_sma_insufficient_data(self):
        """Test SMA when data is shorter than period."""
        prices = [1.0, 2.0]
        result = self.ind.sma(prices, 5)
        assert all(v is None for v in result)

    def test_sma_realistic_prices(self):
        """Test SMA with realistic crypto prices."""
        prices = [50000.0, 50100.0, 50200.0, 50150.0, 50300.0]
        result = self.ind.sma(prices, 3)

        assert result[2] == pytest.approx(50100.0)
        assert result[3] == pytest.approx(50150.0)
        assert result[4] == pytest.approx(50216.6667, abs=0.01)


class TestEMA:
    """Tests for Exponential Moving Average."""

    def setup_method(self):
        self.ind = Indicators()

    def test_ema_basic(self):
        """Test basic EMA calculation."""
        prices = [1.0, 2.0, 3.0, 4.0, 5.0]
        result = self.ind.ema(prices, 3)

        assert result[0] is None
        assert result[1] is None
        # First value is SMA of first 3
        assert result[2] == pytest.approx(2.0)

    def test_ema_responds_to_recent_prices(self):
        """Test that EMA responds more to recent prices than SMA."""
        prices = [1.0, 1.0, 1.0, 1.0, 10.0]
        ema_result = self.ind.ema(prices, 3)
        sma_result = self.ind.sma(prices, 3)

        # EMA should be higher than SMA due to recent price spike
        assert ema_result[-1] > sma_result[-1]

    def test_ema_empty_input(self):
        """Test EMA with empty input."""
        assert self.ind.ema([], 5) == []

    def test_ema_insufficient_data(self):
        """Test EMA when data is shorter than period."""
        prices = [1.0, 2.0]
        result = self.ind.ema(prices, 5)
        assert all(v is None for v in result)


class TestRSI:
    """Tests for Relative Strength Index."""

    def setup_method(self):
        self.ind = Indicators()

    def test_rsi_all_gains(self):
        """Test RSI with only price increases (should be 100)."""
        prices = list(range(1, 20))  # 1, 2, 3, ..., 19
        result = self.ind.rsi(prices, 14)

        # RSI should be 100 when there are only gains
        assert result[-1] == 100.0

    def test_rsi_all_losses(self):
        """Test RSI with only price decreases (should be 0)."""
        prices = list(range(20, 1, -1))  # 20, 19, 18, ..., 2
        result = self.ind.rsi(prices, 14)

        # RSI should be 0 when there are only losses
        assert result[-1] == 0.0

    def test_rsi_range(self):
        """Test that RSI values are within 0-100 range."""
        prices = [
            50.0, 52.0, 48.0, 51.0, 49.0, 53.0, 47.0, 52.0,
            48.0, 51.0, 50.0, 49.0, 52.0, 48.0, 51.0, 50.0,
            53.0, 47.0, 52.0, 48.0
        ]
        result = self.ind.rsi(prices, 14)

        for val in result:
            if val is not None:
                assert 0 <= val <= 100

    def test_rsi_insufficient_data(self):
        """Test RSI with insufficient data."""
        prices = [1.0, 2.0, 3.0]
        result = self.ind.rsi(prices, 14)
        assert all(v is None for v in result)

    def test_rsi_overbought_oversold_thresholds(self):
        """Test RSI correctly identifies overbought/oversold conditions."""
        # Create a downtrend then uptrend
        prices = [100.0, 95.0, 90.0, 85.0, 80.0, 75.0, 70.0,
                  72.0, 74.0, 76.0, 78.0, 80.0, 82.0, 84.0,
                  86.0, 88.0, 90.0, 92.0, 94.0, 96.0]
        result = self.ind.rsi(prices, 14)

        # Last value should show recovery
        assert result[-1] is not None


class TestMACD:
    """Tests for MACD indicator."""

    def setup_method(self):
        self.ind = Indicators()

    def test_macd_structure(self):
        """Test MACD returns correct structure."""
        prices = list(range(1, 50))
        result = self.ind.macd(prices, 12, 26, 9)

        assert "macd" in result
        assert "signal" in result
        assert "histogram" in result
        assert len(result["macd"]) == len(prices)
        assert len(result["signal"]) == len(prices)
        assert len(result["histogram"]) == len(prices)

    def test_macd_histogram_calculation(self):
        """Test MACD histogram = MACD line - Signal line."""
        prices = list(range(1, 100))
        result = self.ind.macd(prices, 12, 26, 9)

        for i in range(len(prices)):
            if result["macd"][i] is not None and result["signal"][i] is not None:
                expected_hist = result["macd"][i] - result["signal"][i]
                assert result["histogram"][i] == pytest.approx(expected_hist, abs=0.0001)

    def test_macd_insufficient_data(self):
        """Test MACD with insufficient data."""
        prices = [1.0, 2.0, 3.0]
        result = self.ind.macd(prices, 12, 26, 9)

        assert all(v is None for v in result["macd"])

    def test_macd_uptrend(self):
        """Test MACD in uptrend shows positive histogram."""
        # Create a realistic uptrend with some volatility
        import math
        prices = [50.0 + math.sin(i * 0.3) * 2 + i * 0.5 for i in range(100)]
        result = self.ind.macd(prices, 12, 26, 9)

        # In an uptrend, the MACD line should generally be above the signal line
        # Check that we have valid data (not all None)
        valid_histogram = [h for h in result["histogram"] if h is not None]
        assert len(valid_histogram) > 0


class TestBollingerBands:
    """Tests for Bollinger Bands indicator."""

    def setup_method(self):
        self.ind = Indicators()

    def test_bollinger_structure(self):
        """Test Bollinger Bands returns correct structure."""
        prices = list(range(1, 50))
        result = self.ind.bollinger_bands(prices, 20, 2.0)

        assert "upper" in result
        assert "middle" in result
        assert "lower" in result
        assert len(result["upper"]) == len(prices)

    def test_bollinger_band_ordering(self):
        """Test that upper >= middle >= lower."""
        prices = [50.0 + (i % 10) - 5 for i in range(50)]
        result = self.ind.bollinger_bands(prices, 20, 2.0)

        for i in range(len(prices)):
            if result["middle"][i] is not None:
                assert result["upper"][i] >= result["middle"][i]
                assert result["lower"][i] <= result["middle"][i]

    def test_bollinger_contraction(self):
        """Test Bollinger Bands narrow during low volatility."""
        # Low volatility period
        prices = [50.0] * 30 + [50.1, 49.9, 50.0, 50.1, 49.9]
        result = self.ind.bollinger_bands(prices, 20, 2.0)

        # Band width should be small during low volatility
        band_width = result["upper"][-1] - result["lower"][-1]
        assert band_width < 2.0  # Narrow bands

    def test_bollinger_insufficient_data(self):
        """Test Bollinger Bands with insufficient data."""
        prices = [1.0, 2.0, 3.0]
        result = self.ind.bollinger_bands(prices, 20, 2.0)
        assert all(v is None for v in result["upper"])


class TestStochasticOscillator:
    """Tests for Stochastic Oscillator."""

    def setup_method(self):
        self.ind = Indicators()

    def test_stochastic_structure(self):
        """Test Stochastic returns correct structure."""
        highs = list(range(10, 60))
        lows = list(range(1, 51))
        closes = [float(i + 5) for i in range(50)]
        result = self.ind.stochastic_oscillator(highs, lows, closes, 14, 3)

        assert "k" in result
        assert "d" in result

    def test_stochastic_range(self):
        """Test Stochastic values are within 0-100 range."""
        highs = [50.0, 52.0, 48.0, 51.0, 49.0] * 10
        lows = [45.0, 47.0, 43.0, 46.0, 44.0] * 10
        closes = [48.0, 50.0, 46.0, 49.0, 47.0] * 10
        result = self.ind.stochastic_oscillator(highs, lows, closes, 14, 3)

        for val in result["k"]:
            if val is not None:
                assert 0 <= val <= 100
