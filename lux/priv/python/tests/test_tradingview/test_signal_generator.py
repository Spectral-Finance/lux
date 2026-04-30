"""Unit tests for TradingView Signal Generator."""

import pytest
from tradingview.signal_generator import SignalGenerator


class TestSignalGenerator:
    """Tests for trading signal generation."""

    def setup_method(self):
        self.gen = SignalGenerator()

    def _create_test_indicators(self, rsi_val, macd_hist, price, bb_upper, bb_lower, sma20, sma50):
        """Helper to create test indicator data."""
        idx = 19
        closes = [price] * 20
        rsi = [None] * 19 + [rsi_val]
        macd = {
            "macd": [None] * 19 + [0.001],
            "signal": [None] * 19 + [0.0],
            "histogram": [None] * 19 + [macd_hist]
        }
        bollinger = {
            "upper": [None] * 19 + [bb_upper],
            "middle": [None] * 19 + [(bb_upper + bb_lower) / 2],
            "lower": [None] * 19 + [bb_lower]
        }
        sma_20 = [None] * 19 + [sma20]
        sma_50 = [None] * 19 + [sma50]

        return closes, rsi, macd, bollinger, sma_20, sma_50

    def test_empty_input(self):
        """Test signal generation with empty input."""
        result = self.gen.generate_signals([], [], {}, {}, [], [])
        assert result["consensus"] == "neutral"
        assert result["strength"] == 0

    def test_rsi_oversold_buy_signal(self):
        """Test RSI oversold generates buy signal."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=25.0,  # Oversold
            macd_hist=0.0,
            price=50000.0,
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["rsi"]["signal"] == "buy"
        assert result["individual_signals"]["rsi"]["strength"] > 0

    def test_rsi_overbought_sell_signal(self):
        """Test RSI overbought generates sell signal."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=75.0,  # Overbought
            macd_hist=0.0,
            price=50000.0,
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["rsi"]["signal"] == "sell"

    def test_rsi_neutral(self):
        """Test RSI in neutral zone."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=50.0,  # Neutral
            macd_hist=0.0,
            price=50000.0,
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["rsi"]["signal"] == "neutral"

    def test_macd_positive_histogram(self):
        """Test MACD positive histogram generates buy signal."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=50.0,
            macd_hist=0.001,  # Positive
            price=50000.0,
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["macd"]["signal"] == "buy"

    def test_macd_negative_histogram(self):
        """Test MACD negative histogram generates sell signal."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=50.0,
            macd_hist=-0.001,  # Negative
            price=50000.0,
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["macd"]["signal"] == "sell"

    def test_bollinger_lower_band_buy(self):
        """Test price at lower Bollinger Band generates buy signal."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=50.0,
            macd_hist=0.0,
            price=48000.0,  # At lower band
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["bollinger_bands"]["signal"] == "buy"

    def test_bollinger_upper_band_sell(self):
        """Test price at upper Bollinger Band generates sell signal."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=50.0,
            macd_hist=0.0,
            price=52000.0,  # At upper band
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=50000.0,
            sma50=49000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["individual_signals"]["bollinger_bands"]["signal"] == "sell"

    def test_sma_crossover_golden_cross(self):
        """Test SMA golden cross generates buy signal."""
        idx = 19
        closes = [50000.0] * 20
        rsi = [None] * 19 + [50.0]
        macd = {
            "macd": [None] * 19 + [0.0],
            "signal": [None] * 19 + [0.0],
            "histogram": [None] * 19 + [0.0]
        }
        bb = {
            "upper": [None] * 19 + [52000.0],
            "middle": [None] * 19 + [50000.0],
            "lower": [None] * 19 + [48000.0]
        }
        # Golden cross: SMA20 crosses above SMA50
        sma_20 = [None] * 19 + [50100.0]  # Currently above
        sma_50 = [None] * 19 + [50000.0]

        # Need to set up previous values for crossover detection
        sma_20[-2] = 49900.0  # Previously below
        sma_50[-2] = 50000.0

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma_20, sma_50)

        assert result["individual_signals"]["sma_crossover"]["signal"] == "buy"

    def test_sma_crossover_death_cross(self):
        """Test SMA death cross generates sell signal."""
        closes = [50000.0] * 20
        rsi = [None] * 19 + [50.0]
        macd = {
            "macd": [None] * 19 + [0.0],
            "signal": [None] * 19 + [0.0],
            "histogram": [None] * 19 + [0.0]
        }
        bb = {
            "upper": [None] * 19 + [52000.0],
            "middle": [None] * 19 + [50000.0],
            "lower": [None] * 19 + [48000.0]
        }
        # Death cross: SMA20 crosses below SMA50
        sma_20 = [None] * 19 + [49900.0]  # Currently below
        sma_50 = [None] * 19 + [50000.0]
        sma_20[-2] = 50100.0  # Previously above
        sma_50[-2] = 50000.0

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma_20, sma_50)

        assert result["individual_signals"]["sma_crossover"]["signal"] == "sell"

    def test_consensus_buy(self):
        """Test consensus calculation with majority buy signals."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=25.0,  # Buy
            macd_hist=0.001,  # Buy
            price=48000.0,  # At lower BB = Buy
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=49000.0,  # Price above SMA = Buy
            sma50=48000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["consensus"] == "buy"
        assert result["strength"] > 0

    def test_consensus_sell(self):
        """Test consensus calculation with majority sell signals."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=75.0,  # Sell
            macd_hist=-0.001,  # Sell
            price=52000.0,  # At upper BB = Sell
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=51000.0,  # Price below SMA = Sell
            sma50=52000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        assert result["consensus"] == "sell"
        assert result["strength"] > 0

    def test_output_structure(self):
        """Test output has correct structure."""
        closes = [50000.0] * 20
        rsi = [None] * 19 + [50.0]
        macd = {
            "macd": [None] * 19 + [0.0],
            "signal": [None] * 19 + [0.0],
            "histogram": [None] * 19 + [0.0]
        }
        bb = {
            "upper": [None] * 19 + [52000.0],
            "middle": [None] * 19 + [50000.0],
            "lower": [None] * 19 + [48000.0]
        }
        sma_20 = [None] * 19 + [50000.0]
        sma_50 = [None] * 19 + [49000.0]

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma_20, sma_50)

        assert "consensus" in result
        assert "strength" in result
        assert "individual_signals" in result
        assert "reasoning" in result
        assert isinstance(result["reasoning"], list)

    def test_reasoning_populated_on_signals(self):
        """Test that reasoning is populated when signals are generated."""
        closes, rsi, macd, bb, sma20, sma50 = self._create_test_indicators(
            rsi_val=25.0,
            macd_hist=0.001,
            price=50000.0,
            bb_upper=52000.0,
            bb_lower=48000.0,
            sma20=49000.0,
            sma50=48000.0
        )

        result = self.gen.generate_signals(closes, rsi, macd, bb, sma20, sma50)

        # Should have reasoning for at least RSI and MACD signals
        assert len(result["reasoning"]) >= 2
        assert all(isinstance(r, str) for r in result["reasoning"])
