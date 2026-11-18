"""
Lux.YouTube.ContentIntelligence
Production-grade YouTube analytics and recommendation system for autonomous agents.
"""

import re
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from pydantic import BaseModel, Field

# --- Models ---
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

class TitleScore(BaseModel):
    score: int
    feedback: List[str]
    has_power_words: bool
    has_brackets: bool

# --- Intelligence System ---
class YouTubeContentIntelligence:
    
    POWER_WORDS = {"secret", "exposed", "truth", "never", "insane", "why", "stop", "genius"}
    
    def __init__(self, channel_id: str):
        self.channel_id = channel_id

    # 1. Performance Analytics & Velocity Engine
    def analyze_performance(self, views: int, hours_live: float, avd_sec: float, video_len_sec: float, historical_vph: float) -> PerformanceMetrics:
        vph = round(views / hours_live, 2) if hours_live > 0 else 0
        velocity_score = round(vph / historical_vph, 2) if historical_vph > 0 else 1.0
        apv = round((avd_sec / video_len_sec) * 100, 2) if video_len_sec > 0 else 0
        
        flags = []
        if apv < 30: flags.append("Mid-video valley detected")
        if velocity_score > 1.5: flags.append("High velocity - potential viral trajectory")
        
        return PerformanceMetrics(
            vph=vph,
            velocity_score=velocity_score,
            avd_seconds=avd_sec,
            apv_percentage=apv,
            retention_flags=flags
        )

    # 2. Audience Engagement & Loyalty Modeling
    def grade_engagement(self, likes: int, views: int, comments: int) -> EngagementMetrics:
        like_ratio = likes / views if views > 0 else 0
        comment_density = (comments / (views / 1000)) if views >= 1000 else comments
        
        # Grading Matrix
        if like_ratio >= 0.05 and comment_density >= 5: grade = "S"
        elif like_ratio >= 0.04 and comment_density >= 3: grade = "A"
        elif like_ratio >= 0.03 and comment_density >= 1.5: grade = "B"
        elif like_ratio >= 0.02: grade = "C"
        else: grade = "F"
        
        return EngagementMetrics(grade=grade, like_ratio=round(like_ratio, 4), comment_density=round(comment_density, 2))

    # 3. Content Recommendation & Gap Discovery
    def discover_content_gaps(self, audience_search_terms: List[str], channel_tags: List[str]) -> List[str]:
        # Identifies search demand that is missing from the channel's current catalog
        channel_tags_lower = {tag.lower() for tag in channel_tags}
        return [term for term in audience_search_terms if term.lower() not in channel_tags_lower]

    # 4. Optimal Upload Timing Prediction
    def predict_posting_time(self, peak_audience_hour: int) -> Dict[str, str]:
        # Accounts for 45 mins lead-time processing buffer before peak traffic
        optimal_time = (datetime.today().replace(hour=peak_audience_hour, minute=0) - timedelta(minutes=45))
        return {
            "peak_hour": f"{peak_audience_hour}:00",
            "optimal_upload_time": optimal_time.strftime("%H:%M"),
            "score": ":optimal"
        }

    # 5. Title & Thumbnail CTR Optimizer
    def optimize_title_ctr(self, title: str) -> TitleScore:
        score = 50 # Base score
        feedback = []
        
        has_brackets = bool(re.search(r"[\[\]\(\)]", title))
        if has_brackets:
            score += 15
            feedback.append("Brackets/Parentheses detected (+15)")
            
        has_numbers = bool(re.search(r"\d", title))
        if has_numbers:
            score += 15
            feedback.append("Numbers detected (+15)")
            
        title_words = set(re.findall(r"\w+", title.lower()))
        has_power_words = bool(title_words.intersection(self.POWER_WORDS))
        if has_power_words:
            score += 20
            feedback.append("Power/Psychological words detected (+20)")
            
        if len(title) > 60:
            score -= 10
            feedback.append("Title too long, might truncate on mobile (-10)")
            
        return TitleScore(
            score=min(score, 100),
            feedback=feedback,
            has_power_words=has_power_words,
            has_brackets=has_brackets
        )
