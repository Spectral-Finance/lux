"""
Price Tracking Engine for NFT Collections.
Computes floor prices, volume metrics, 24h delta, outlier filtering, and technical trend indicators.
"""

from __future__ import annotations

import math
import statistics
from typing import Any, Dict, List, Optional, Tuple
import time

from lux.nft.types import (
    MovingAverages,
    PriceTrendAnalysis,
    SaleEvent,
    TrendDirection,
)


class PriceTrackingEngine:
    """
    High-performance price tracking and quantitative trend analysis engine.
    Calculates moving averages, VWAP, volatility, support/resistance, and 24h percentage deltas.
    """

    def __init__(self, iqr_multiplier: float = 1.5):
        self.iqr_multiplier = iqr_multiplier

    def filter_price_outliers(self, prices: List[float]) -> Tuple[List[float], int]:
        """
        Filters price anomalies (wash trading / manipulation) using Interquartile Range (IQR).
        Returns (filtered_prices, outliers_count).
        """
        if len(prices) < 4:
            return prices, 0

        sorted_prices = sorted(prices)
        n = len(sorted_prices)
        q1_idx = int(0.25 * n)
        q3_idx = int(0.75 * n)

        q1 = sorted_prices[q1_idx]
        q3 = sorted_prices[q3_idx]
        iqr = q3 - q1

        lower_bound = max(0.0, q1 - self.iqr_multiplier * iqr)
        upper_bound = q3 + self.iqr_multiplier * iqr

        filtered = [p for p in prices if lower_bound <= p <= upper_bound]
        outliers_count = len(prices) - len(filtered)
        return filtered, outliers_count

    def calculate_vwap(self, sales: List[SaleEvent]) -> float:
        """
        Computes Volume-Weighted Average Price (VWAP).
        VWAP = sum(Price_i * Volume_i) / sum(Volume_i)
        For NFTs, volume per sale is typically 1 unit unless bundled.
        """
        if not sales:
            return 0.0

        total_dollar_volume = sum(sale.price_eth for sale in sales)
        total_units = len(sales)

        return (total_dollar_volume / total_units) if total_units > 0 else 0.0

    def calculate_sma(self, values: List[float], period: int) -> Optional[float]:
        """Calculates Simple Moving Average over `period` data points."""
        if len(values) < period or period <= 0:
            return None
        window = values[-period:]
        return sum(window) / period

    def calculate_ema(self, values: List[float], period: int, alpha: Optional[float] = None) -> Optional[float]:
        """
        Calculates Exponential Moving Average over `period` data points.
        Smoothing factor alpha defaults to 2 / (period + 1).
        """
        if len(values) < period or period <= 0:
            return None

        if alpha is None:
            alpha = 2.0 / (period + 1.0)

        ema = sum(values[:period]) / period
        for val in values[period:]:
            ema = (val * alpha) + (ema * (1.0 - alpha))

        return ema

    def calculate_volatility(self, prices: List[float]) -> float:
        """
        Calculates price volatility (standard deviation of log returns).
        """
        if len(prices) < 2:
            return 0.0

        log_returns = []
        for i in range(1, len(prices)):
            if prices[i - 1] > 0 and prices[i] > 0:
                log_returns.append(math.log(prices[i] / prices[i - 1]))

        if len(log_returns) < 2:
            return 0.0

        try:
            return statistics.stdev(log_returns)
        except Exception:
            return 0.0

    def calculate_support_resistance(
        self, prices: List[float], current_price: float
    ) -> Tuple[float, float]:
        """
        Estimates support and resistance levels from price distribution quantiles.
        """
        if not prices:
            return max(0.0, current_price * 0.95), current_price * 1.05

        sorted_prices = sorted(prices)
        n = len(sorted_prices)

        # 15th percentile as support, 85th percentile as resistance
        p15_idx = max(0, min(n - 1, int(0.15 * n)))
        p85_idx = max(0, min(n - 1, int(0.85 * n)))

        support = sorted_prices[p15_idx]
        resistance = sorted_prices[p85_idx]

        if support >= current_price and current_price > 0:
            support = current_price * 0.95
        if resistance <= current_price and current_price > 0:
            resistance = current_price * 1.05

        return support, resistance

    def classify_trend(
        self,
        current_floor: float,
        floor_24h_ago: float,
        price_change_percent: float,
        volume_change_percent: float,
        sma_7: Optional[float],
        sma_24: Optional[float],
    ) -> TrendDirection:
        """
        Classifies market trend into BULLISH, BEARISH, BREAKOUT, DUMPING, or NEUTRAL.
        """
        if price_change_percent > 15.0 and volume_change_percent > 30.0:
            return TrendDirection.BREAKOUT
        if price_change_percent < -15.0 and volume_change_percent > 30.0:
            return TrendDirection.DUMPING

        if sma_7 and sma_24:
            if sma_7 > sma_24 and price_change_percent > 2.0:
                return TrendDirection.BULLISH
            elif sma_7 < sma_24 and price_change_percent < -2.0:
                return TrendDirection.BEARISH

        if price_change_percent >= 5.0:
            return TrendDirection.BULLISH
        elif price_change_percent <= -5.0:
            return TrendDirection.BEARISH

        return TrendDirection.NEUTRAL

    def analyze_price_trends(
        self,
        collection_address: str,
        current_floor_eth: float,
        historical_sales: List[SaleEvent],
        floor_history_hourly: Optional[List[float]] = None,
        reference_timestamp: Optional[float] = None,
    ) -> PriceTrendAnalysis:
        """
        Performs a full quantitative price analysis and historical trend breakdown.
        """
        ref_ts = reference_timestamp or time.time()
        ts_24h_ago = ref_ts - 86400.0
        ts_48h_ago = ref_ts - (86400.0 * 2)

        # Partition sales into 24h current and 24h previous windows
        sales_24h_curr = [s for s in historical_sales if ts_24h_ago <= s.timestamp <= ref_ts]
        sales_24h_prev = [s for s in historical_sales if ts_48h_ago <= s.timestamp < ts_24h_ago]

        # Extract prices
        raw_prices_24h = [s.price_eth for s in sales_24h_curr if s.price_eth > 0]
        filtered_prices_24h, outliers_count = self.filter_price_outliers(raw_prices_24h)

        # Volumes
        volume_24h_eth = sum(s.price_eth for s in sales_24h_curr)
        volume_24h_prev_eth = sum(s.price_eth for s in sales_24h_prev)

        if volume_24h_prev_eth > 0:
            vol_change_pct = ((volume_24h_eth - volume_24h_prev_eth) / volume_24h_prev_eth) * 100.0
        else:
            vol_change_pct = 100.0 if volume_24h_eth > 0 else 0.0

        # Floor 24h ago
        if floor_history_hourly and len(floor_history_hourly) >= 24:
            floor_24h_ago_eth = floor_history_hourly[-24]
        elif filtered_prices_24h:
            floor_24h_ago_eth = min(filtered_prices_24h)
        else:
            floor_24h_ago_eth = current_floor_eth

        price_change_eth = current_floor_eth - floor_24h_ago_eth
        if floor_24h_ago_eth > 0:
            price_change_pct = (price_change_eth / floor_24h_ago_eth) * 100.0
        else:
            price_change_pct = 0.0

        # VWAP & Volatility
        vwap_24h = self.calculate_vwap(sales_24h_curr)
        volatility_24h = self.calculate_volatility(filtered_prices_24h or raw_prices_24h)

        # Moving Averages based on hourly floor history or sequential sale prices
        series = floor_history_hourly if floor_history_hourly else [s.price_eth for s in historical_sales]
        sma_7 = self.calculate_sma(series, 7)
        sma_24 = self.calculate_sma(series, 24)
        sma_30 = self.calculate_sma(series, 30)
        ema_7 = self.calculate_ema(series, 7)
        ema_24 = self.calculate_ema(series, 24)

        moving_averages = MovingAverages(
            sma_7=round(sma_7, 6) if sma_7 is not None else None,
            sma_24=round(sma_24, 6) if sma_24 is not None else None,
            sma_30=round(sma_30, 6) if sma_30 is not None else None,
            ema_7=round(ema_7, 6) if ema_7 is not None else None,
            ema_24=round(ema_24, 6) if ema_24 is not None else None,
        )

        support, resistance = self.calculate_support_resistance(
            filtered_prices_24h or raw_prices_24h, current_floor_eth
        )

        # Liquidity index: turnover rate (sales per 24 hours normalized)
        liquidity_index = round(min(1.0, len(sales_24h_curr) / 50.0), 4)

        trend_direction = self.classify_trend(
            current_floor=current_floor_eth,
            floor_24h_ago=floor_24h_ago_eth,
            price_change_percent=price_change_pct,
            volume_change_percent=vol_change_pct,
            sma_7=sma_7,
            sma_24=sma_24,
        )

        return PriceTrendAnalysis(
            collection_address=collection_address.lower(),
            current_floor_eth=round(current_floor_eth, 6),
            floor_24h_ago_eth=round(floor_24h_ago_eth, 6),
            price_change_24h_eth=round(price_change_eth, 6),
            price_change_24h_percent=round(price_change_pct, 4),
            volume_24h_eth=round(volume_24h_eth, 4),
            volume_24h_ago_eth=round(volume_24h_prev_eth, 4),
            volume_change_24h_percent=round(vol_change_pct, 4),
            vwap_24h_eth=round(vwap_24h, 6),
            volatility_24h=round(volatility_24h, 6),
            moving_averages=moving_averages,
            trend_direction=trend_direction,
            liquidity_index=liquidity_index,
            support_level_eth=round(support, 6),
            resistance_level_eth=round(resistance, 6),
            outliers_filtered_count=outliers_count,
            analyzed_sales_count=len(sales_24h_curr),
            timestamp=ref_ts,
        )
