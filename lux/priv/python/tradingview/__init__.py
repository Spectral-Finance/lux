"""TradingView Technical Analysis Integration for Spectral Finance Lux.

This package provides technical analysis indicators and signal generation
compatible with TradingView-style analysis, integrated into the Lux framework
via Python-Elixir interop.

## Components

- `indicators`: Core technical indicators (RSI, MACD, Bollinger Bands, SMA, EMA)
- `price_fetcher`: Price data fetching from Binance public API
- `signal_generator`: Trading signal generation based on indicator analysis

## Usage

    from tradingview import TechnicalAnalyzer
    analyzer = TechnicalAnalyzer()
    result = analyzer.analyze("BTCUSDT", "1h")

"""

from tradingview.indicators import Indicators
from tradingview.price_fetcher import PriceFetcher
from tradingview.signal_generator import SignalGenerator

__all__ = ["Indicators", "PriceFetcher", "SignalGenerator", "TechnicalAnalyzer"]


class TechnicalAnalyzer:
    """Main entry point for technical analysis.

    Combines price fetching, indicator calculation, and signal generation
    into a single convenient interface.

    ## Examples

        analyzer = TechnicalAnalyzer()
        result = analyzer.analyze("BTCUSDT", "1d")
        print(result["signals"])
    """

    def __init__(self):
        self.price_fetcher = PriceFetcher()
        self.indicators = Indicators()
        self.signal_generator = SignalGenerator()

    def analyze(self, symbol, interval="1h", period=100):
        """Perform complete technical analysis on a symbol.

        Args:
            symbol: Trading pair symbol (e.g., 'BTCUSDT', 'ETHUSDT')
            interval: Kline interval ('1m', '5m', '15m', '1h', '4h', '1d')
            period: Number of candles to fetch for analysis

        Returns:
            dict: Complete analysis result with indicators and signals
        """
        # Fetch price data
        price_data = self.price_fetcher.get_klines(symbol, interval, period)
        if not price_data:
            return {"error": f"No price data available for {symbol}"}

        closes = [float(candle["close"]) for candle in price_data]
        highs = [float(candle["high"]) for candle in price_data]
        lows = [float(candle["low"]) for candle in price_data]
        volumes = [float(candle["volume"]) for candle in price_data]

        # Calculate indicators
        rsi = self.indicators.rsi(closes)
        macd = self.indicators.macd(closes)
        bollinger = self.indicators.bollinger_bands(closes)
        sma_20 = self.indicators.sma(closes, 20)
        sma_50 = self.indicators.sma(closes, 50)
        ema_12 = self.indicators.ema(closes, 12)
        ema_26 = self.indicators.ema(closes, 26)

        # Generate signals
        signals = self.signal_generator.generate_signals(
            closes, rsi, macd, bollinger, sma_20, sma_50
        )

        return {
            "symbol": symbol,
            "interval": interval,
            "current_price": closes[-1],
            "indicators": {
                "rsi": rsi,
                "macd": macd,
                "bollinger_bands": bollinger,
                "sma_20": sma_20[-1] if sma_20 else None,
                "sma_50": sma_50[-1] if sma_50 else None,
                "ema_12": ema_12[-1] if ema_12 else None,
                "ema_26": ema_26[-1] if ema_26 else None,
            },
            "signals": signals,
            "price_data": price_data,
        }
