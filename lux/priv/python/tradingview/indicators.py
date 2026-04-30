"""Technical Analysis Indicators.

Provides core technical indicator calculations including:
- RSI (Relative Strength Index)
- MACD (Moving Average Convergence Divergence)
- Bollinger Bands
- SMA (Simple Moving Average)
- EMA (Exponential Moving Average)

All functions are pure Python implementations with no external dependencies,
designed for integration with the Lux Elixir framework.

## Usage

    from tradingview.indicators import Indicators
    ind = Indicators()
    rsi_values = ind.rsi(closing_prices)
"""

from typing import List, Optional, Dict, Any


class Indicators:
    """Technical analysis indicator calculations.

    All methods accept lists of floats (typically closing prices) and return
    lists of indicator values. The returned lists may be shorter than the input
    due to warm-up periods required by each indicator.
    """

    def sma(self, prices: List[float], period: int = 20) -> List[Optional[float]]:
        """Calculate Simple Moving Average.

        Args:
            prices: List of price values
            period: Number of periods for the moving average

        Returns:
            List of SMA values, with None for periods before the warm-up is complete
        """
        if not prices or period <= 0 or len(prices) < period:
            return [None] * len(prices) if prices else []

        result = [None] * (period - 1)
        for i in range(period - 1, len(prices)):
            window = prices[i - period + 1 : i + 1]
            result.append(sum(window) / period)

        return result

    def ema(self, prices: List[float], period: int = 12) -> List[Optional[float]]:
        """Calculate Exponential Moving Average.

        Uses the standard EMA formula with smoothing factor 2/(period+1).

        Args:
            prices: List of price values
            period: Number of periods for the EMA

        Returns:
            List of EMA values, with None for periods before the warm-up is complete
        """
        if not prices or period <= 0 or len(prices) < period:
            return [None] * len(prices) if prices else []

        multiplier = 2.0 / (period + 1)

        # Initialize with SMA of first 'period' values
        result = [None] * (period - 1)
        sma_value = sum(prices[:period]) / period
        result.append(sma_value)

        # Calculate EMA for remaining values
        for i in range(period, len(prices)):
            ema_value = (prices[i] - result[-1]) * multiplier + result[-1]
            result.append(ema_value)

        return result

    def rsi(
        self, prices: List[float], period: int = 14
    ) -> List[Optional[float]]:
        """Calculate Relative Strength Index.

        Uses Wilder's smoothing method (exponential moving average) for
        average gains and losses, matching TradingView's default RSI.

        Args:
            prices: List of price values (closing prices)
            period: RSI period (default 14)

        Returns:
            List of RSI values (0-100), with None for warm-up periods
        """
        if not prices or period <= 0 or len(prices) < period + 1:
            return [None] * len(prices) if prices else []

        # Calculate price changes
        changes = [prices[i] - prices[i - 1] for i in range(1, len(prices))]

        # Separate gains and losses
        gains = [max(0, change) for change in changes]
        losses = [max(0, -change) for change in changes]

        # Initial average gain/loss (simple average of first 'period' values)
        avg_gain = sum(gains[:period]) / period
        avg_loss = sum(losses[:period]) / period

        result = [None] * period  # Warm-up period

        # Calculate initial RSI
        if avg_loss == 0:
            result.append(100.0)
        else:
            rs = avg_gain / avg_loss
            result.append(100.0 - (100.0 / (1.0 + rs)))

        # Wilder's smoothing for remaining values
        multiplier = 1.0 / period
        for i in range(period, len(changes)):
            avg_gain = (avg_gain * (period - 1) + gains[i]) * multiplier
            avg_loss = (avg_loss * (period - 1) + losses[i]) * multiplier

            if avg_loss == 0:
                rsi_value = 100.0
            else:
                rs = avg_gain / avg_loss
                rsi_value = 100.0 - (100.0 / (1.0 + rs))

            result.append(rsi_value)

        return result

    def macd(
        self,
        prices: List[float],
        fast_period: int = 12,
        slow_period: int = 26,
        signal_period: int = 9,
    ) -> Dict[str, List[Optional[float]]]:
        """Calculate MACD (Moving Average Convergence Divergence).

        Returns MACD line, signal line, and histogram values.

        Args:
            prices: List of price values
            fast_period: Fast EMA period (default 12)
            slow_period: Slow EMA period (default 26)
            signal_period: Signal line EMA period (default 9)

        Returns:
            Dict with keys 'macd', 'signal', 'histogram', each containing
            a list of values with None for warm-up periods
        """
        if not prices or slow_period > len(prices):
            empty = [None] * len(prices)
            return {"macd": empty, "signal": empty, "histogram": empty}

        # Calculate fast and slow EMAs
        fast_ema = self.ema(prices, fast_period)
        slow_ema = self.ema(prices, slow_period)

        # MACD line = Fast EMA - Slow EMA
        macd_line = []
        for i in range(len(prices)):
            if fast_ema[i] is not None and slow_ema[i] is not None:
                macd_line.append(fast_ema[i] - slow_ema[i])
            else:
                macd_line.append(None)

        # Find the first valid MACD value for signal line calculation
        first_valid = None
        for i, val in enumerate(macd_line):
            if val is not None:
                first_valid = i
                break

        if first_valid is None:
            return {"macd": macd_line, "signal": [None] * len(prices), "histogram": [None] * len(prices)}

        # Signal line = EMA of MACD line
        valid_macd = [v for v in macd_line[first_valid:] if v is not None]
        signal_ema = self.ema(valid_macd, signal_period)

        # Reconstruct signal line with proper alignment
        signal_line = [None] * first_valid
        signal_line.extend(signal_ema)

        # Pad if needed
        while len(signal_line) < len(prices):
            signal_line.append(None)

        # Histogram = MACD - Signal
        histogram = []
        for i in range(len(prices)):
            if macd_line[i] is not None and signal_line[i] is not None:
                histogram.append(macd_line[i] - signal_line[i])
            else:
                histogram.append(None)

        return {
            "macd": macd_line[: len(prices)],
            "signal": signal_line[: len(prices)],
            "histogram": histogram[: len(prices)],
        }

    def bollinger_bands(
        self, prices: List[float], period: int = 20, std_dev: float = 2.0
    ) -> Dict[str, List[Optional[float]]]:
        """Calculate Bollinger Bands.

        Consists of a middle band (SMA), upper band (SMA + k*stddev),
        and lower band (SMA - k*stddev).

        Args:
            prices: List of price values
            period: SMA period for middle band (default 20)
            std_dev: Number of standard deviations for bands (default 2.0)

        Returns:
            Dict with keys 'upper', 'middle', 'lower'
        """
        if not prices or period <= 0 or len(prices) < period:
            empty = [None] * len(prices)
            return {"upper": empty, "middle": empty, "lower": empty}

        middle = self.sma(prices, period)

        upper = []
        lower = []

        for i in range(len(prices)):
            if middle[i] is None:
                upper.append(None)
                lower.append(None)
            else:
                # Calculate standard deviation of the window
                window = prices[i - period + 1 : i + 1]
                mean = middle[i]
                variance = sum((x - mean) ** 2 for x in window) / period
                std = variance**0.5

                upper.append(middle[i] + std_dev * std)
                lower.append(middle[i] - std_dev * std)

        return {"upper": upper, "middle": middle, "lower": lower}

    def stochastic_oscillator(
        self,
        highs: List[float],
        lows: List[float],
        closes: List[float],
        k_period: int = 14,
        d_period: int = 3,
    ) -> Dict[str, List[Optional[float]]]:
        """Calculate Stochastic Oscillator (%K and %D).

        Args:
            highs: List of high prices
            lows: List of low prices
            closes: List of close prices
            k_period: %K period (default 14)
            d_period: %D smoothing period (default 3)

        Returns:
            Dict with keys 'k' and 'd'
        """
        min_length = max(len(highs), len(lows), len(closes))
        if min_length < k_period:
            empty = [None] * min_length
            return {"k": empty, "d": empty}

        # Calculate %K
        k_values = []
        for i in range(k_period - 1, min_length):
            high_max = max(highs[i - k_period + 1 : i + 1])
            low_min = min(lows[i - k_period + 1 : i + 1])

            if high_max == low_min:
                k_values.append(50.0)  # Neutral value
            else:
                k = ((closes[i] - low_min) / (high_max - low_min)) * 100
                k_values.append(k)

        # %D is SMA of %K
        d_values = self.sma(k_values, d_period)

        # Pad with None at the beginning
        pad_length = k_period - 1
        result_k = [None] * pad_length + k_values
        result_d = [None] * (pad_length + d_period - 1) + d_values[d_period - 1 :]

        return {"k": result_k, "d": result_d}
