"""Revenue optimization tools for YouTube channels.

Estimates monetization outcomes from view volume / RPM / CPM, compares content
segments, and produces concrete optimization suggestions.
"""
from __future__ import annotations

from typing import Dict, List, Sequence

from .models import VideoMetrics


def estimate_revenue(views: int, rpm: float = 3.0, cpm: float = 6.0) -> Dict[str, float]:
    """RPM = revenue per 1000 views; CPM is what advertisers pay.

    Returns estimated gross revenue and net (after YouTube 45% rev-share).
    """
    gross = views / 1000.0 * rpm
    net = gross * 0.55
    return {"views": float(views), "rpm": rpm, "cpm": cpm,
            "gross_usd": round(gross, 2), "net_usd": round(net, 2)}


def segment_revenue(videos: Sequence[VideoMetrics], rpm: float = 3.0) -> List[Dict]:
    """Per-video revenue estimates sorted by net contribution (descending)."""
    rows = []
    for v in videos:
        est = estimate_revenue(v.view_count, rpm)
        rows.append({
            "video_id": v.video_id,
            "title": v.title,
            "views": v.view_count,
            "engagement_rate": v.engagement_rate,
            "estimated_net_usd": est["net_usd"],
        })
    rows.sort(key=lambda r: r["estimated_net_usd"], reverse=True)
    return rows


def optimization_tips(videos: Sequence[VideoMetrics]) -> List[str]:
    """Rule-based recommendations from observed metrics."""
    tips: List[str] = []
    if videos:
        er = [v.engagement_rate for v in videos if v.view_count > 0]
        avg_er = sum(er) / len(er) if er else 0.0
        if avg_er < 0.03:
            tips.append("平均互动率偏低：强化结尾 CTA 与评论区互动，提升 like/comment 密度。")
        if any(v.duration_seconds > 1200 for v in videos):
            tips.append("长视频占比高：检查完播率，长内容需分段钩子维持留存。")
        short = [v for v in videos if v.duration_seconds and v.duration_seconds < 180]
        if short and sum(v.view_count for v in short) / len(short) > (sum(v.view_count for v in videos) / len(videos) if videos else 0):
            tips.append("短视频表现优于均值：可加大 Shorts 频次以拉新。")
        if not tips:
            tips.append("核心指标健康：保持更新节奏，继续放大高互动主题。")
    else:
        tips.append("暂无视频数据，先完成数据采集再评估。")
    return tips
