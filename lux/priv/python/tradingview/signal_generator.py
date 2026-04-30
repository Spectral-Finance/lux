"""Trading Signal Generator.

Generates buy/sell/neutral signals based on technical indicator analysis.
Combines multiple indicators to produce a consensus signal with strength rating.

## Usage

    from tradingview.signal_generator import SignalGenerator
    gen = SignalGenerator()
    signals = gen.generate_signals(closes, rsi, macd, bollinger, sma_20, sma_50)
"""

from typing import List, Optional, Dict, Any


class SignalGenerator:
    """Generates trading signals from technical indicators.

    Analyzes multiple indicators and produces:
    - Individual indicator signals (buy/sell/neutral)
    - A consensus signal based on majority voting
    - Signal strength (0-100)
    - Detailed reasoning for each signal

    ## Signal Strength

    - 80-100: Strong signal
    - 60-79: Moderate signal
    - 40-59: Weak signal
    - 0-39: No clear signal
    """

    # RSI thresholds
    RSI_OVERSOLD = 30
    RSI_OVERBOUGHT = 70

    # MACD crossover detection
    MACD_MIN_DIFFERENCE = 0.0001  # Minimum difference to consider significant

    def generate_signals(
        self,
        closes: List[float],
        rsi: List[Optional[float]],
        macd: Dict[str, List[Optional[float]]],
        bollinger: Dict[str, List[Optional[float]]],
        sma_20: List[Optional[float]],
        sma_50: List[Optional[float]],
    ) -> Dict[str, Any]:
        """Generate trading signals from multiple indicators.

        Args:
            closes: List of closing prices
            rsi: RSI values from Indicators.rsi()
            macd: MACD dict from Indicators.macd()
            bollinger: Bollinger Bands dict from Indicators.bollinger_bands()
            sma_20: 20-period SMA values
            sma_50: 50-period SMA values

        Returns:
            Dict containing:
            - 'consensus': Overall signal ('buy', 'sell', 'neutral')
            - 'strength': Signal strength (0-100)
            - 'individual_signals': Dict of signals per indicator
            - 'reasoning': List of signal reasons
        """
        if not closes:
            return self._empty_signal()

        # Get latest values
        idx = len(closes) - 1
        current_price = closes[-1]

        individual_signals = {}
        reasoning = []

        # RSI Signal
        rsi_signal = self._rsi_signal(rsi, idx)
        individual_signals["rsi"] = rsi_signal
        if rsi_signal["signal"] != "neutral":
            reasoning.append(rsi_signal["reason"])

        # MACD Signal
        macd_signal = self._macd_signal(macd, idx)
        individual_signals["macd"] = macd_signal
        if macd_signal["signal"] != "neutral":
            reasoning.append(macd_signal["reason"])

        # Bollinger Bands Signal
        bb_signal = self._bollinger_signal(bollinger, current_price, idx)
        individual_signals["bollinger_bands"] = bb_signal
        if bb_signal["signal"] != "neutral":
            reasoning.append(bb_signal["reason"])

        # SMA Crossover Signal
        sma_signal = self._sma_crossover_signal(sma_20, sma_50, current_price, idx)
        individual_signals["sma_crossover"] = sma_signal
        if sma_signal["signal"] != "neutral":
            reasoning.append(sma_signal["reason"])

        # Price vs SMA Signal
        price_sma_signal = self._price_vs_sma_signal(
            current_price, sma_20, sma_50, idx
        )
        individual_signals["price_vs_sma"] = price_sma_signal
        if price_sma_signal["signal"] != "neutral":
            reasoning.append(price_sma_signal["reason"])

        # Calculate consensus
        consensus = self._calculate_consensus(individual_signals)

        return {
            "consensus": consensus["signal"],
            "strength": consensus["strength"],
            "individual_signals": individual_signals,
            "reasoning": reasoning,
        }

    def _rsi_signal(
        self, rsi: List[Optional[float]], idx: int
    ) -> Dict[str, Any]:
        """Generate signal from RSI indicator."""
        if idx >= len(rsi) or rsi[idx] is None:
            return {"signal": "neutral", "strength": 0, "reason": "RSI data unavailable"}

        rsi_value = rsi[idx]

        if rsi_value <= self.RSI_OVERSOLD:
            strength = min(100, int((self.RSI_OVERSOLD - rsi_value) / self.RSI_OVERSOLD * 100))
            return {
                "signal": "buy",
                "strength": strength,
                "reason": f"RSI at {rsi_value:.1f} indicates oversold conditions",
            }
        elif rsi_value >= self.RSI_OVERBOUGHT:
            strength = min(100, int((rsi_value - self.RSI_OVERBOUGHT) / (100 - self.RSI_OVERBOUGHT) * 100))
            return {
                "signal": "sell",
                "strength": strength,
                "reason": f"RSI at {rsi_value:.1f} indicates overbought conditions",
            }
        else:
            return {
                "signal": "neutral",
                "strength": 0,
                "reason": f"RSI at {rsi_value:.1f} is in neutral territory",
            }

    def _macd_signal(
        self, macd: Dict[str, List[Optional[float]]], idx: int
    ) -> Dict[str, Any]:
        """Generate signal from MACD indicator."""
        macd_line = macd.get("macd", [])
        signal_line = macd.get("signal", [])
        histogram = macd.get("histogram", [])

        if (
            idx >= len(macd_line)
            or macd_line[idx] is None
            or signal_line[idx] is None
        ):
            return {"signal": "neutral", "strength": 0, "reason": "MACD data unavailable"}

        macd_val = macd_line[idx]
        signal_val = signal_line[idx]
        hist_val = histogram[idx] if idx < len(histogram) and histogram[idx] is not None else 0

        # Check for crossover
        if idx > 0 and macd_line[idx - 1] is not None and signal_line[idx - 1] is not None:
            prev_diff = macd_line[idx - 1] - signal_line[idx - 1]
            curr_diff = macd_val - signal_val

            # Bullish crossover: MACD crosses above signal
            if prev_diff <= 0 and curr_diff > 0:
                return {
                    "signal": "buy",
                    "strength": 75,
                    "reason": "MACD bullish crossover detected (MACD crossed above signal)",
                }

            # Bearish crossover: MACD crosses below signal
            if prev_diff >= 0 and curr_diff < 0:
                return {
                    "signal": "sell",
                    "strength": 75,
                    "reason": "MACD bearish crossover detected (MACD crossed below signal)",
                }

        # Trend following based on histogram
        if hist_val > 0:
            return {
                "signal": "buy",
                "strength": 40,
                "reason": f"MACD histogram positive ({hist_val:.6f}), bullish momentum",
            }
        elif hist_val < 0:
            return {
                "signal": "sell",
                "strength": 40,
                "reason": f"MACD histogram negative ({hist_val:.6f}), bearish momentum",
            }

        return {
            "signal": "neutral",
            "strength": 0,
            "reason": "MACD shows no clear direction",
        }

    def _bollinger_signal(
        self,
        bollinger: Dict[str, List[Optional[float]]],
        current_price: float,
        idx: int,
    ) -> Dict[str, Any]:
        """Generate signal from Bollinger Bands."""
        upper = bollinger.get("upper", [])
        lower = bollinger.get("lower", [])
        middle = bollinger.get("middle", [])

        if idx >= len(upper) or upper[idx] is None:
            return {"signal": "neutral", "strength": 0, "reason": "Bollinger Bands data unavailable"}

        upper_val = upper[idx]
        lower_val = lower[idx]
        middle_val = middle[idx] if idx < len(middle) and middle[idx] is not None else None

        # Price touching lower band = oversold
        if current_price <= lower_val:
            return {
                "signal": "buy",
                "strength": 70,
                "reason": f"Price ({current_price:.2f}) at or below lower Bollinger Band ({lower_val:.2f})",
            }

        # Price touching upper band = overbought
        if current_price >= upper_val:
            return {
                "signal": "sell",
                "strength": 70,
                "reason": f"Price ({current_price:.2f}) at or above upper Bollinger Band ({upper_val:.2f})",
            }

        # Price near middle band = neutral
        if middle_val is not None:
            band_width = upper_val - lower_val
            if band_width > 0:
                price_position = (current_price - lower_val) / band_width
                if price_position < 0.3:
                    return {
                        "signal": "buy",
                        "strength": 30,
                        "reason": f"Price in lower portion of Bollinger Bands (position: {price_position:.2f})",
                    }
                elif price_position > 0.7:
                    return {
                        "signal": "sell",
                        "strength": 30,
                        "reason": f"Price in upper portion of Bollinger Bands (position: {price_position:.2f})",
                    }

        return {
            "signal": "neutral",
            "strength": 0,
            "reason": "Price within normal Bollinger Band range",
        }

    def _sma_crossover_signal(
        self,
        sma_20: List[Optional[float]],
        sma_50: List[Optional[float]],
        current_price: float,
        idx: int,
    ) -> Dict[str, Any]:
        """Generate signal from SMA crossover analysis."""
        if idx < 1:
            return {"signal": "neutral", "strength": 0, "reason": "Insufficient data for crossover analysis"}

        # Check for golden cross (SMA20 crosses above SMA50)
        if (
            sma_20[idx] is not None
            and sma_50[idx] is not None
            and sma_20[idx - 1] is not None
            and sma_50[idx - 1] is not None
        ):
            prev_diff = sma_20[idx - 1] - sma_50[idx - 1]
            curr_diff = sma_20[idx] - sma_50[idx]

            # Golden cross
            if prev_diff <= 0 and curr_diff > 0:
                return {
                    "signal": "buy",
                    "strength": 80,
                    "reason": "Golden cross detected (SMA20 crossed above SMA50)",
                }

            # Death cross
            if prev_diff >= 0 and curr_diff < 0:
                return {
                    "signal": "sell",
                    "strength": 80,
                    "reason": "Death cross detected (SMA20 crossed below SMA50)",
                }

            # Ongoing trend
            if curr_diff > 0:
                return {
                    "signal": "buy",
                    "strength": 40,
                    "reason": f"SMA20 ({sma_20[idx]:.2f}) above SMA50 ({sma_50[idx]:.2f}), uptrend",
                }
            else:
                return {
                    "signal": "sell",
                    "strength": 40,
                    "reason": f"SMA20 ({sma_20[idx]:.2f}) below SMA50 ({sma_50[idx]:.2f}), downtrend",
                }

        return {
            "signal": "neutral",
            "strength": 0,
            "reason": "SMA crossover data unavailable",
        }

    def _price_vs_sma_signal(
        self,
        current_price: float,
        sma_20: List[Optional[float]],
        sma_50: List[Optional[float]],
        idx: int,
    ) -> Dict[str, Any]:
        """Generate signal based on price position relative to SMAs."""
        if idx >= len(sma_20) or sma_20[idx] is None:
            return {"signal": "neutral", "strength": 0, "reason": "SMA20 data unavailable"}

        sma_20_val = sma_20[idx]
        sma_50_val = sma_50[idx] if idx < len(sma_50) and sma_50[idx] is not None else None

        # Price above both SMAs = bullish
        if current_price > sma_20_val and (sma_50_val is None or current_price > sma_50_val):
            return {
                "signal": "buy",
                "strength": 50,
                "reason": f"Price ({current_price:.2f}) above key moving averages",
            }

        # Price below both SMAs = bearish
        if current_price < sma_20_val and (sma_50_val is None or current_price < sma_50_val):
            return {
                "signal": "sell",
                "strength": 50,
                "reason": f"Price ({current_price:.2f}) below key moving averages",
            }

        return {
            "signal": "neutral",
            "strength": 0,
            "reason": "Price between moving averages, mixed signals",
        }

    def _calculate_consensus(
        self, individual_signals: Dict[str, Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Calculate consensus signal from individual indicator signals."""
        buy_count = 0
        sell_count = 0
        total_weighted_strength = 0
        active_indicators = 0

        for name, signal in individual_signals.items():
            sig = signal.get("signal", "neutral")
            strength = signal.get("strength", 0)

            if sig == "buy":
                buy_count += 1
                total_weighted_strength += strength
                active_indicators += 1
            elif sig == "sell":
                sell_count += 1
                total_weighted_strength += strength
                active_indicators += 1

        total_indicators = len(individual_signals)

        if buy_count > sell_count:
            strength = int(
                (total_weighted_strength / total_indicators) * (buy_count / total_indicators)
            )
            return {"signal": "buy", "strength": min(100, strength)}
        elif sell_count > buy_count:
            strength = int(
                (total_weighted_strength / total_indicators) * (sell_count / total_indicators)
            )
            return {"signal": "sell", "strength": min(100, strength)}
        else:
            return {"signal": "neutral", "strength": 0}

    def _empty_signal(self) -> Dict[str, Any]:
        """Return an empty signal result."""
        return {
            "consensus": "neutral",
            "strength": 0,
            "individual_signals": {},
            "reasoning": ["No data available for analysis"],
        }
