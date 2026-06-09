"""Configuration management for Twitter automation system."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional
import json
import os
from pathlib import Path


@dataclass
class SchedulerConfig:
    """Configuration for tweet scheduling."""
    enabled: bool = True
    max_scheduled_per_day: int = 50
    min_interval_minutes: int = 15
    default_timezone: str = "UTC"
    retry_on_failure: bool = True
    max_retries: int = 3


@dataclass
class EngagementConfig:
    """Configuration for engagement rules."""
    enabled: bool = True
    max_likes_per_hour: int = 50
    max_retweets_per_hour: int = 30
    max_replies_per_hour: int = 20
    max_follows_per_day: int = 100
    max_unfollows_per_day: int = 50
    cooldown_minutes: int = 5
    sentiment_threshold: float = 0.5


@dataclass
class ContentConfig:
    """Configuration for content curation."""
    enabled: bool = True
    max_sources: int = 10
    refresh_interval_minutes: int = 60
    min_relevance_score: float = 0.3
    max_curated_per_day: int = 30
    rss_feeds: List[str] = field(default_factory=list)
    keywords: List[str] = field(default_factory=list)


@dataclass
class DMConfig:
    """Configuration for DM automation."""
    enabled: bool = True
    max_dms_per_hour: int = 30
    max_dms_per_day: int = 200
    require_follow_back: bool = True
    min_account_age_days: int = 7
    templates: Dict[str, str] = field(default_factory=dict)


@dataclass
class AutomationConfig:
    """Main configuration for automation system."""
    scheduler: SchedulerConfig = field(default_factory=SchedulerConfig)
    engagement: EngagementConfig = field(default_factory=EngagementConfig)
    content: ContentConfig = field(default_factory=ContentConfig)
    dm: DMConfig = field(default_factory=DMConfig)
    data_dir: str = "./data/automation"
    log_level: str = "INFO"
    
    @classmethod
    def from_file(cls, path: str) -> "AutomationConfig":
        """Load configuration from JSON file."""
        path = Path(path)
        if not path.exists():
            return cls()
        
        with open(path, 'r') as f:
            data = json.load(f)
        
        config = cls()
        if 'scheduler' in data:
            config.scheduler = SchedulerConfig(**data['scheduler'])
        if 'engagement' in data:
            config.engagement = EngagementConfig(**data['engagement'])
        if 'content' in data:
            config.content = ContentConfig(**data['content'])
        if 'dm' in data:
            config.dm = DMConfig(**data['dm'])
        if 'data_dir' in data:
            config.data_dir = data['data_dir']
        if 'log_level' in data:
            config.log_level = data['log_level']
        
        return config
    
    def save(self, path: str) -> None:
        """Save configuration to JSON file."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        
        data = {
            'scheduler': self.scheduler.__dict__,
            'engagement': self.engagement.__dict__,
            'content': self.content.__dict__,
            'dm': self.dm.__dict__,
            'data_dir': self.data_dir,
            'log_level': self.log_level
        }
        
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)