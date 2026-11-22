"""
youtube_intel.models — lightweight machine-learning models implemented from
scratch in pure Python (stdlib only).

These cover the "Machine learning models for content optimization" and
"Performance prediction system" acceptance criteria of lux issue #69 without
pulling in numpy / scikit-learn:

  * :class:`LinearRegression` — ordinary least squares via the closed-form
    normal equation (Gaussian elimination). Used to model how title length,
    tag count, etc. drive views.
  * :class:`LogisticRegression` — binary classification trained with batch
    gradient descent. Used to predict whether a video will be "high performing".
  * :class:`PostingTimeOptimizer` — learns the best hour-of-week to publish from
    historical engagement, with smoothing so sparse data degrades gracefully.
  * :class:`PerformancePredictor` — ties the regressors together into a single
    ``predict(features)`` call returning an expected-views estimate plus a
    confidence band derived from residual variance.

Everything is deterministic and dependency-free so it drops straight into the
lux monorepo.
"""

from __future__ import annotations

import math
from statistics import mean, pstdev
from typing import Dict, List, Optional, Sequence, Tuple

__all__ = [
    "LinearRegression",
    "LogisticRegression",
    "PostingTimeOptimizer",
    "PerformancePredictor",
]


# --------------------------------------------------------------------------- #
# Linear algebra helpers (pure Python)
# --------------------------------------------------------------------------- #
def _transpose(a: List[List[float]]) -> List[List[float]]:
    return [list(col) for col in zip(*a)]


def _matmul(a: List[List[float]], b: List[List[float]]) -> List[List[float]]:
    bt = _transpose(b)
    return [[sum(x * y for x, y in zip(row, col)) for col in bt] for row in a]


def _matvec(a: List[List[float]], v: List[float]) -> List[float]:
    return [sum(x * y for x, y in zip(row, v)) for row in a]


def _identity(n: int) -> List[List[float]]:
    return [[1.0 if i == j else 0.0 for j in range(n)] for i in range(n)]


def _gaussian_solve(a: List[List[float]], b: List[float]) -> List[float]:
    """Solve ``a x = b`` via Gaussian elimination with partial pivoting."""
    n = len(a)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        # pivot
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        if abs(m[pivot][col]) < 1e-12:
            raise ValueError("singular matrix")
        m[col], m[pivot] = m[pivot], m[col]
        pv = m[col][col]
        for r in range(n):
            if r == col:
                continue
            factor = m[r][col] / pv
            if factor == 0.0:
                continue
            for c in range(col, n + 1):
                m[r][c] -= factor * m[col][c]
    return [m[i][n] / m[i][i] for i in range(n)]


# --------------------------------------------------------------------------- #
# Linear regression (closed-form OLS with L2 / ridge option)
# --------------------------------------------------------------------------- #
class LinearRegression:
    """Ordinary least squares linear regression.

    Fits ``y = X w`` by solving the (optionally ridge-regularised) normal
    equation ``(XᵀX + λI) w = Xᵀy``. A bias/intercept term is added
    automatically when ``fit_intercept`` is True.

    Parameters
    ----------
    l2:
        Ridge penalty λ. ``0`` gives plain OLS.
    fit_intercept:
        Prepend a column of ones so the model learns a bias term.
    """

    def __init__(self, l2: float = 0.0, fit_intercept: bool = True) -> None:
        self.l2 = l2
        self.fit_intercept = fit_intercept
        self.weights: List[float] = []
        self._n_features = 0

    def _design(self, x: Sequence[Sequence[float]]) -> List[List[float]]:
        rows: List[List[float]] = []
        for row in x:
            r = list(row)
            if self.fit_intercept:
                r = [1.0] + r
            rows.append(r)
        return rows

    def fit(self, x: Sequence[Sequence[float]],
            y: Sequence[float]) -> "LinearRegression":
        if len(x) != len(y):
            raise ValueError("x and y must have the same length")
        if not x:
            raise ValueError("cannot fit on empty data")
        design = self._design(x)
        self._n_features = len(design[0])
        xt = _transpose(design)
        xtx = _matmul(xt, design)
        xty = _matvec(xt, list(y))
        if self.l2:
            reg = _identity(self._n_features)
            start = 1 if self.fit_intercept else 0  # don't penalise bias
            for i in range(start, self._n_features):
                reg[i][i] = self.l2
            for i in range(self._n_features):
                for j in range(self._n_features):
                    xtx[i][j] += reg[i][j]
        self.weights = _gaussian_solve(xtx, xty)
        return self

    def predict(self, x: Sequence[Sequence[float]]) -> List[float]:
        if not self.weights:
            raise ValueError("model is not fitted")
        design = self._design(x)
        return _matvec(design, self.weights)

    def predict_one(self, x: Sequence[float]) -> float:
        return self.predict([x])[0]

    def score(self, x: Sequence[Sequence[float]],
              y: Sequence[float]) -> float:
        """Coefficient of determination R²."""
        preds = self.predict(x)
        ybar = mean(y)
        ss_tot = sum((yi - ybar) ** 2 for yi in y)
        ss_res = sum((yi - pi) ** 2 for yi, pi in zip(y, preds))
        if ss_tot == 0:
            return 1.0 if ss_res == 0 else 0.0
        return 1.0 - ss_res / ss_tot

    def residuals(self, x: Sequence[Sequence[float]],
                  y: Sequence[float]) -> List[float]:
        return [yi - pi for yi, pi in zip(y, self.predict(x))]

    def residual_std(self, x: Sequence[Sequence[float]],
                     y: Sequence[float]) -> float:
        res = self.residuals(x, y)
        return pstdev(res) if len(res) > 1 else 0.0


# --------------------------------------------------------------------------- #
# Logistic regression (batch gradient descent)
# --------------------------------------------------------------------------- #
def _sigmoid(z: float) -> float:
    if z >= 0:
        return 1.0 / (1.0 + math.exp(-z))
    ez = math.exp(z)
    return ez / (1.0 + ez)


class LogisticRegression:
    """Binary logistic regression trained with batch gradient descent.

    Predicts ``P(y=1 | x)`` for a 0/1 label. Useful for "will this video be a
    hit?" classification. Pure Python, deterministic.
    """

    def __init__(self, learning_rate: float = 0.1, epochs: int = 500,
                 l2: float = 0.0, fit_intercept: bool = True) -> None:
        self.learning_rate = learning_rate
        self.epochs = epochs
        self.l2 = l2
        self.fit_intercept = fit_intercept
        self.weights: List[float] = []

    def _design(self, x: Sequence[Sequence[float]]) -> List[List[float]]:
        rows: List[List[float]] = []
        for row in x:
            r = list(row)
            if self.fit_intercept:
                r = [1.0] + r
            rows.append(r)
        return rows

    def fit(self, x: Sequence[Sequence[float]],
            y: Sequence[int]) -> "LogisticRegression":
        if len(x) != len(y):
            raise ValueError("x and y must have the same length")
        if not x:
            raise ValueError("cannot fit on empty data")
        design = self._design(x)
        n = len(design[0])
        self.weights = [0.0] * n
        m = len(design)
        start = 1 if self.fit_intercept else 0
        for _ in range(self.epochs):
            grad = [0.0] * n
            for row, label in zip(design, y):
                pred = _sigmoid(sum(w * f for w, f in zip(self.weights, row)))
                err = pred - label
                for j in range(n):
                    grad[j] += err * row[j]
            for j in range(n):
                reg = self.l2 * self.weights[j] if j >= start else 0.0
                self.weights[j] -= self.learning_rate * (grad[j] / m + reg)
        return self

    def predict_proba(self, x: Sequence[Sequence[float]]) -> List[float]:
        if not self.weights:
            raise ValueError("model is not fitted")
        return [_sigmoid(sum(w * f for w, f in zip(self.weights, row)))
                for row in self._design(x)]

    def predict(self, x: Sequence[Sequence[float]],
                threshold: float = 0.5) -> List[int]:
        return [1 if p >= threshold else 0 for p in self.predict_proba(x)]

    def score(self, x: Sequence[Sequence[float]],
              y: Sequence[int]) -> float:
        """Mean classification accuracy."""
        preds = self.predict(x)
        correct = sum(1 for p, t in zip(preds, y) if p == t)
        return correct / len(y) if y else 0.0


# --------------------------------------------------------------------------- #
# Posting-time optimizer
# --------------------------------------------------------------------------- #
class PostingTimeOptimizer:
    """Learn the best hour-of-week to publish from historical engagement.

    Engagement is aggregated into 7×24 = 168 buckets (day-of-week × hour). Each
    bucket's mean engagement is smoothed toward the global mean with a
    Bayesian-style prior (``smoothing`` pseudo-count) so sparse buckets don't
    win by luck. ``best_times`` returns the top buckets ranked by smoothed score.
    """

    DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    def __init__(self, smoothing: float = 2.0) -> None:
        self.smoothing = smoothing
        self._sums: Dict[int, float] = {}
        self._counts: Dict[int, int] = {}
        self._global_sum = 0.0
        self._global_n = 0

    @staticmethod
    def _bucket(day: int, hour: int) -> int:
        return (day % 7) * 24 + (hour % 24)

    def add(self, day: int, hour: int, engagement: float) -> None:
        """Record one observation. ``day`` is 0=Mon..6=Sun, ``hour`` 0..23."""
        b = self._bucket(day, hour)
        self._sums[b] = self._sums.get(b, 0.0) + engagement
        self._counts[b] = self._counts.get(b, 0) + 1
        self._global_sum += engagement
        self._global_n += 1

    def fit(self, observations: Sequence[Tuple[int, int, float]]) -> \
            "PostingTimeOptimizer":
        """Fit from an iterable of ``(day, hour, engagement)`` tuples."""
        for day, hour, eng in observations:
            self.add(day, hour, eng)
        return self

    def _global_mean(self) -> float:
        return self._global_sum / self._global_n if self._global_n else 0.0

    def score(self, day: int, hour: int) -> float:
        """Smoothed expected engagement for a (day, hour) slot."""
        b = self._bucket(day, hour)
        n = self._counts.get(b, 0)
        s = self._sums.get(b, 0.0)
        prior = self._global_mean()
        return (s + self.smoothing * prior) / (n + self.smoothing)

    def best_times(self, top_k: int = 5) -> List[Dict[str, float]]:
        """Return the ``top_k`` best (day, hour) slots ranked by score."""
        if not self._counts:
            return []
        scored = []
        for b in self._sums:
            day, hour = divmod(b, 24)
            scored.append({
                "day": day,
                "day_name": self.DAYS[day],
                "hour": hour,
                "score": self.score(day, hour),
                "samples": self._counts.get(b, 0),
            })
        scored.sort(key=lambda d: d["score"], reverse=True)
        return scored[:top_k]

    def best_slot(self) -> Optional[Dict[str, float]]:
        best = self.best_times(top_k=1)
        return best[0] if best else None


# --------------------------------------------------------------------------- #
# Performance predictor
# --------------------------------------------------------------------------- #
class PerformancePredictor:
    """End-to-end view-count predictor.

    Combines a :class:`LinearRegression` over engineered video features with a
    residual-variance confidence band, and optionally a
    :class:`LogisticRegression` hit classifier. Satisfies the "Performance
    prediction system" acceptance criterion.

    Engineered features (in order):
        [title_len, tag_count, description_len, has_thumbnail, hour, day]
    """

    FEATURE_NAMES = [
        "title_len", "tag_count", "description_len",
        "has_thumbnail", "hour", "day",
    ]

    def __init__(self, l2: float = 1.0) -> None:
        self.regressor = LinearRegression(l2=l2, fit_intercept=True)
        self._fitted = False
        self._resid_std = 0.0
        self._train_x: List[List[float]] = []
        self._train_y: List[float] = []

    @staticmethod
    def featurize(video: Dict[str, object]) -> List[float]:
        """Turn a raw video dict into the model's numeric feature vector."""
        title = str(video.get("title", ""))
        tags = video.get("tags") or []
        desc = str(video.get("description", ""))
        snippet = video.get("snippet", {}) if isinstance(video.get("snippet"), dict) else {}
        title = str(snippet.get("title", title))
        desc = str(snippet.get("description", desc))
        tags = snippet.get("tags", tags) or []
        published = video.get("published_hour", video.get("hour", 12))
        day = video.get("published_day", video.get("day", 0))
        has_thumb = 1.0 if video.get("has_thumbnail", True) else 0.0
        return [
            float(len(title)),
            float(len(tags)),
            float(len(desc)),
            has_thumb,
            float(published),
            float(day),
        ]

    def fit(self, videos: Sequence[Dict[str, object]]) -> "PerformancePredictor":
        """Fit on a list of video dicts each carrying a ``views`` field."""
        xs = [self.featurize(v) for v in videos]
        ys = [float(v.get("views", 0)) for v in videos]
        if not xs:
            raise ValueError("cannot fit on empty data")
        self.regressor.fit(xs, ys)
        self._train_x = xs
        self._train_y = ys
        self._resid_std = self.regressor.residual_std(xs, ys)
        self._fitted = True
        return self

    def predict(self, video: Dict[str, object]) -> Dict[str, float]:
        """Predict expected views with a ±1σ confidence band."""
        if not self._fitted:
            raise ValueError("predictor is not fitted")
        x = self.featurize(video)
        point = self.regressor.predict_one(x)
        return {
            "predicted_views": max(0.0, point),
            "lower": max(0.0, point - self._resid_std),
            "upper": max(0.0, point + self._resid_std),
            "confidence_std": self._resid_std,
        }

    def feature_importance(self) -> Dict[str, float]:
        """Absolute standardised-ish weight per feature (larger = stronger)."""
        if not self._fitted:
            raise ValueError("predictor is not fitted")
        weights = self.regressor.weights
        offset = 1 if self.regressor.fit_intercept else 0
        importance = {}
        for i, name in enumerate(self.FEATURE_NAMES):
            importance[name] = abs(weights[i + offset])
        return importance