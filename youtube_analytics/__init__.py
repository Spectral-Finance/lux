"""YouTube Analytics & Growth Engine — Lux bounty #72 implementation.

A real, runnable analytics and growth-optimization system for YouTube channels:
data collection, growth prediction, revenue optimization, automated reporting.
"""
from .collector import YouTubeCollector
from .models import ChannelMetrics, VideoMetrics, CommentItem, AnalyticsSnapshot
from .prediction import predict_growth, linear_regression, exponential_smoothing, cmgr
from .revenue import estimate_revenue, segment_revenue, optimization_tips
from .reporting import build_report, export_csv

__all__ = [
    "YouTubeCollector",
    "ChannelMetrics", "VideoMetrics", "CommentItem", "AnalyticsSnapshot",
    "predict_growth", "linear_regression", "exponential_smoothing", "cmgr",
    "estimate_revenue", "segment_revenue", "optimization_tips",
    "build_report", "export_csv",
]

__version__ = "1.0.0"
