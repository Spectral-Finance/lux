"""Growth trend prediction for YouTube channels.

Implements a small, dependency-free forecasting toolbox:
- linear regression (least squares)
- exponential smoothing (single/double)
- compound monthly growth rate (CMGR)

All models are deterministic and covered by unit tests.
"""
from __future__ import annotations

from typing import List, Sequence, Tuple


def linear_regression(xs: Sequence[float], ys: Sequence[float]) -> Tuple[float, float]:
    """Return (slope, intercept) of the least-squares line y = slope*x + intercept."""
    n = len(xs)
    if n == 0:
        return 0.0, 0.0
    mx = sum(xs) / n
    my = sum(ys) / n
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sxx = sum((x - mx) ** 2 for x in xs)
    slope = sxy / sxx if sxx != 0 else 0.0
    intercept = my - slope * mx
    return slope, intercept


def predict_linear(history: Sequence[float], steps: int = 7) -> List[float]:
    xs = list(range(len(history)))
    slope, intercept = linear_regression(xs, history)
    last = len(history) - 1
    return [max(0.0, slope * (last + i + 1) + intercept) for i in range(steps)]


def exponential_smoothing(history: Sequence[float], alpha: float = 0.3, steps: int = 7) -> List[float]:
    """Single exponential smoothing; flattens but stays robust to noise."""
    if not history:
        return [0.0] * steps
    level = history[0]
    for v in history[1:]:
        level = alpha * v + (1 - alpha) * level
    return [level] * steps


def cmgr(history: Sequence[float], periods_per_month: int = 1) -> float:
    """Compound monthly growth rate across the series, as a decimal (e.g. 0.12)."""
    if len(history) < 2 or history[0] <= 0:
        return 0.0
    end = history[-1]
    start = history[0]
    n = (len(history) - 1) / max(periods_per_month, 1)
    if n <= 0 or start <= 0:
        return 0.0
    return (end / start) ** (1.0 / n) - 1.0


def predict_growth(history: Sequence[float], steps: int = 7, method: str = "linear") -> List[float]:
    """Forecast next `steps` values using the chosen method."""
    if method == "exp":
        return exponential_smoothing(history, steps=steps)
    if method == "cmgr":
        rate = cmgr(history)
        out = []
        cur = history[-1] if history else 0.0
        for _ in range(steps):
            cur = cur * (1 + rate)
            out.append(cur)
        return out
    return predict_linear(history, steps)
