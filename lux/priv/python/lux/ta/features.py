"""Multi-timeframe analysis, alert management and strategy backtesting.

This module builds on :class:`lux.ta.client.TradingViewClient` to provide the
higher-level features requested in issue #86:

* :func:`multi_timeframe_analysis` - run the TA pipeline across several
  timeframes and aggregate a consensus bias (multi-timeframe analysis).
* :class:`AlertDialog` / :class:`AlertManager` - evaluate candles against
  configurable threshold/crossover rules and emit alerts (alert management).
* :func:`backtest` - a minimal, vectorless strategy backtester that replays a
  rule over a candle series and reports trades + performance metrics
  (strategy backtesting verification).

Everything is pure-Python and offline-friendly.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Sequence

from .client import AnalysisResult, Candle, TradingViewClient

__all__ = [
    "TimeframeResult",
    "multi_timeframe_analysis",
    "Alert",
    "AlertDialog",
    "AlertManager",
    "BacktestResult",
    "backtest",
]


# --------------------------------------------------------------------------- #
# Multi-timeframe analysis
# --------------------------------------------------------------------------- #
@dataclass
class TimeframeResult:
    timeframe: str
    bias: str
    signals: List[str]
    indicators: Dict[str, object]


def multi_timeframe_analysis(
    client: TradingViewClient,
    symbol: str,
    timeframes: Sequence[str] = ("1d", "1h", "15m"),
    limit: int = 200,
) -> Dict[str, object]:
    """Analyze ``symbol`` across multiple timeframes and aggregate a consensus.

    Returns a dict with per-timeframe results and an overall ``consensus`` bias
    (``bullish`` / ``bearish`` / ``neutral``) computed by majority vote of the
    per-timeframe biases.
    """
    results: List[TimeframeResult] = []
    for tf in timeframes:
        analysis: AnalysisResult = client.analyze(symbol, timeframe=tf, limit=limit)
        results.append(
            TimeframeResult(
                timeframe=tf,
                bias=analysis.bias,
                signals=analysis.signals,
                indicators=analysis.indicators,
            )
        )

    votes = {"bullish": 0, "bearish": 0, "neutral": 0}
    for r in results:
        votes[r.bias] = votes.get(r.bias, 0) + 1

    # Majority vote; ties resolve to neutral.
    consensus = max(votes, key=lambda k: votes[k])
    if (
        votes["bullish"] == votes["bearish"]
        and votes["bullish"] >= votes["neutral"]
    ):
        consensus = "neutral"

    return {
        "symbol": symbol,
        "timeframes": [r.timeframe for r in results],
        "results": [
            {
                "timeframe": r.timeframe,
                "bias": r.bias,
                "signals": r.signals,
            }
            for r in results
        ],
        "votes": votes,
        "consensus": consensus,
    }


# --------------------------------------------------------------------------- #
# Alert management
# --------------------------------------------------------------------------- #
@dataclass
class Alert:
    """A single fired alert."""

    rule: str
    symbol: str
    message: str
    value: float


@dataclass
class AlertDialog:
    """A configurable alert rule evaluated against each candle/bar.

    Supported ``kind`` values:

    * ``"above"`` / ``"below"`` - close price crosses above/below ``threshold``.
    * ``"rsi_above"`` / ``"rsi_below"`` - RSI(period) crosses the threshold.
    """

    name: str
    kind: str
    threshold: float
    period: int = 14

    def evaluate(self, symbol: str, candles: Sequence[Candle]) -> Optional[Alert]:
        from . import indicators

        closes = [c.close for c in candles]
        if self.kind in ("above", "below"):
            value = closes[-1]
            if self.kind == "above" and value > self.threshold:
                return Alert(self.name, symbol, f"price {value} > {self.threshold}", value)
            if self.kind == "below" and value < self.threshold:
                return Alert(self.name, symbol, f"price {value} < {self.threshold}", value)
            return None

        if self.kind in ("rsi_above", "rsi_below"):
            rsi_series = indicators.rsi(closes, self.period)
            value = next((v for v in reversed(rsi_series) if v is not None), None)
            if value is None:
                return None
            if self.kind == "rsi_above" and value > self.threshold:
                return Alert(self.name, symbol, f"RSI {value:.2f} > {self.threshold}", value)
            if self.kind == "rsi_below" and value < self.threshold:
                return Alert(self.name, symbol, f"RSI {value:.2f} < {self.threshold}", value)
            return None

        raise ValueError(f"unsupported alert kind: {self.kind}")


class AlertManager:
    """Evaluates a collection of :class:`AlertDialog` rules over candles."""

    def __init__(self, dialogs: Optional[Sequence[AlertDialog]] = None) -> None:
        self.dialogs: List[AlertDialog] = list(dialogs or [])

    def add(self, dialog: AlertDialog) -> None:
        self.dialogs.append(dialog)

    def evaluate(
        self, symbol: str, candles: Sequence[Candle]
    ) -> List[Alert]:
        fired: List[Alert] = []
        for dialog in self.dialogs:
            alert = dialog.evaluate(symbol, candles)
            if alert is not None:
                fired.append(alert)
        return fired


# --------------------------------------------------------------------------- #
# Strategy backtesting
# --------------------------------------------------------------------------- #
@dataclass
class BacktestResult:
    symbol: str
    initial_capital: float
    final_capital: float
    trades: int
    wins: int
    losses: int
    equity_curve: List[float] = field(default_factory=list)

    @property
    def total_return_pct(self) -> float:
        if self.initial_capital == 0:
            return 0.0
        return (self.final_capital - self.initial_capital) / self.initial_capital * 100.0

    @property
    def win_rate_pct(self) -> float:
        if self.trades == 0:
            return 0.0
        return self.wins / self.trades * 100.0


def backtest(
    symbol: str,
    candles: Sequence[Candle],
    signal_fn: Callable[[Sequence[Candle]], Optional[int]],
    initial_capital: float = 10_000.0,
    fee_pct: float = 0.0,
) -> BacktestResult:
    """Replay a simple long/flat strategy over ``candles``.

    ``signal_fn`` receives the candles up to and including bar ``i`` and returns
    ``1`` to be long, ``-1``/``0`` to be flat, or ``None`` for no change of the
    current position.  The backtester goes long at the next bar's close and
    applies ``fee_pct`` on each fill.

    This is intentionally a *minimal* long/flat backtester suitable for
    verifying a signal rule end-to-end; it is not a full portfolio simulator.
    """
    if not candles:
        raise ValueError("candles must be non-empty")

    capital = float(initial_capital)
    position = 0.0  # units held
    equity_curve: List[float] = []
    trades = 0
    wins = 0
    losses = 0
    entry_price = 0.0

    for i in range(len(candles)):
        # Execute any pending target decided on the previous bar.
        price = candles[i].close

        # Mark-to-market equity.
        equity = capital + position * price
        equity_curve.append(equity)

        if i == 0:
            continue

        target = signal_fn(candles[: i + 1])
        if target is None:
            continue

        if target == 1 and position == 0.0:
            # Enter long.
            units = capital / (price * (1 + fee_pct / 100.0))
            capital -= units * price * (1 + fee_pct / 100.0)
            position = units
            entry_price = price
            trades += 1
        elif target <= 0 and position > 0.0:
            # Exit long.
            proceeds = position * price * (1 - fee_pct / 100.0)
            capital += proceeds
            pnl = (price - entry_price) * position
            if pnl >= 0:
                wins += 1
            else:
                losses += 1
            position = 0.0

    # Close any open position at the final close.
    if position > 0.0:
        final_price = candles[-1].close
        capital += position * final_price * (1 - fee_pct / 100.0)
        pnl = (final_price - entry_price) * position
        if pnl >= 0:
            wins += 1
        else:
            losses += 1
        position = 0.0

    return BacktestResult(
        symbol=symbol,
        initial_capital=float(initial_capital),
        final_capital=capital,
        trades=trades,
        wins=wins,
        losses=losses,
        equity_curve=equity_curve,
    )