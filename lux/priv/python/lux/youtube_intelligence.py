"""Lux.YouTube.ContentIntelligence — Native Lux Prism for YouTube analytics."""

from typing import Any, Dict, List
from pydantic import BaseModel
from lux.prism import Prism


class PerformanceMetrics(BaseModel):
    vph: float
    velocity_score: float
    avd_seconds: float
    apv_percentage: float
    retention_flags: List[str]


class EngagementMetrics(BaseModel):
    grade: str
    like_ratio: float
    comment_density: float


class YouTubeIntelligencePrism(Prism):
    name = "YouTubeIntelligencePrism"
    description = "Analyzes YouTube video velocity, retention, and engagement metrics."
    input_schema = {
        "type": "object",
        "properties": {
            "views": {"type": "integer"},
            "hours_since_publish": {"type": "number"},
            "likes": {"type": "integer"},
            "comments": {"type": "integer"},
            "avg_view_duration": {"type": "number"},
            "video_duration": {"type": "number"},
        },
        "required": ["views", "hours_since_publish"],
    }
    output_schema = {
        "type": "object",
        "properties": {
            "performance": {"type": "object"},
            "engagement": {"type": "object"},
        },
    }

    @staticmethod
    def new(**kwargs):
        return YouTubeIntelligencePrism(**kwargs)

    def analyze(self, data: Dict[str, Any]) -> Dict[str, Any]:
        views = max(int(data.get("views", 0)), 0)
        hours = max(float(data.get("hours_since_publish", 1.0)), 0.01)
        likes = max(int(data.get("likes", 0)), 0)
        comments = max(int(data.get("comments", 0)), 0)
        avd = max(float(data.get("avg_view_duration", 0.0)), 0.0)
        duration = max(float(data.get("video_duration", 1.0)), 1.0)

        vph = round(views / hours, 2)
        apv = round(min((avd / duration) * 100.0, 100.0), 2)
        flags: List[str] = []
        if apv < 35.0:
            flags.append("low_retention")
        if vph >= 1000.0:
            flags.append("high_velocity")

        like_ratio = round((likes / views) * 100.0, 2) if views > 0 else 0.0
        comment_density = round((comments / views) * 100.0, 3) if views > 0 else 0.0
        grade = "A" if like_ratio >= 5.0 else ("B" if like_ratio >= 2.0 else "C")

        perf = PerformanceMetrics(
            vph=vph,
            velocity_score=round(min(vph / 100.0, 100.0), 2),
            avd_seconds=avd,
            apv_percentage=apv,
            retention_flags=flags,
        )
        eng = EngagementMetrics(
            grade=grade,
            like_ratio=like_ratio,
            comment_density=comment_density,
        )
        return {"performance": perf.model_dump(), "engagement": eng.model_dump()}

    def handler(self, input: Dict[str, Any], context: Any = None) -> Dict[str, Any]:
        return self.analyze(input)