"""Tweet scheduling system with cron-like expressions."""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Callable, Dict, List, Optional, Set
from dataclasses import dataclass, field
from enum import Enum
import json
from pathlib import Path
import pytz
from croniter import croniter
from .config import SchedulerConfig


class ScheduleStatus(Enum):
    """Status of a scheduled tweet."""
    PENDING = "pending"
    SCHEDULED = "scheduled"
    POSTED = "posted"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class ScheduledTweet:
    """Represents a scheduled tweet."""
    id: str
    content: str
    cron_expression: str
    timezone: str = "UTC"
    status: ScheduleStatus = ScheduleStatus.PENDING
    created_at: datetime = field(default_factory=datetime.utcnow)
    scheduled_at: Optional[datetime] = None
    posted_at: Optional[datetime] = None
    media_urls: List[str] = field(default_factory=list)
    tags: List[str] = field(default_factory=list)
    retry_count: int = 0
    
    def get_next_run(self) -> Optional[datetime]:
        """Calculate next run time based on cron expression."""
        try:
            base_time = self.scheduled_at or self.created_at
            cron = croniter(self.cron_expression, base_time)
            next_time = cron.get_next(datetime)
            
            # Apply timezone
            tz = pytz.timezone(self.timezone)
            next_time = next_time.replace(tzinfo=pytz.UTC).astimezone(tz)
            
            return next_time
        except (ValueError, KeyError) as e:
            logging.error(f"Invalid cron expression: {e}")
            return None


class TweetScheduler:
    """Manages tweet scheduling with cron-like expressions."""
    
    def __init__(self, config: SchedulerConfig, tweet_callback: Callable):
        self.config = config
        self.tweet_callback = tweet_callback
        self.scheduled_tweets: Dict[str, ScheduledTweet] = {}
        self.running = False
        self._task: Optional[asyncio.Task] = None
        self._lock = asyncio.Lock()
        
        # Ensure data directory exists
        self.data_dir = Path("./data/scheduler")
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        # Load existing schedules
        self._load_schedules()
    
    def _load_schedules(self) -> None:
        """Load scheduled tweets from disk."""
        schedule_file = self.data_dir / "schedules.json"
        if schedule_file.exists():
            try:
                with open(schedule_file, 'r') as f:
                    data = json.load(f)
                    for item in data:
                        tweet = ScheduledTweet(**item)
                        tweet.status = ScheduleStatus(item['status'])
                        self.scheduled_tweets[tweet.id] = tweet
            except Exception as e:
                logging.error(f"Failed to load schedules: {e}")
    
    def _save_schedules(self) -> None:
        """Save scheduled tweets to disk."""
        schedule_file = self.data_dir / "schedules.json"
        try:
            data = []
            for tweet in self.scheduled_tweets.values():
                item = tweet.__dict__.copy()
                item['status'] = tweet.status.value
                data.append(item)
            
            with open(schedule_file, 'w') as f:
                json.dump(data, f, indent=2, default=str)
        except Exception as e:
            logging.error(f"Failed to save schedules: {e}")
    
    def schedule_tweet(self, content: str, cron_expression: str,
                      timezone: str = "UTC", media_urls: Optional[List[str]] = None,
                      tags: Optional[List[str]] = None) -> str:
        """Schedule a new tweet."""
        import uuid
        
        tweet = ScheduledTweet(
            id=str(uuid.uuid4()),
            content=content,
            cron_expression=cron_expression,
            timezone=timezone,
            media_urls=media_urls or [],
            tags=tags or []
        )
        
        # Validate cron expression
        next_run = tweet.get_next_run()
        if not next_run:
            raise ValueError(f"Invalid cron expression: {cron_expression}")
        
        tweet.scheduled_at = next_run
        tweet.status = ScheduleStatus.SCHEDULED
        
        self.scheduled_tweets[tweet.id] = tweet
        self._save_schedules()
        
        return tweet.id
    
    def cancel_tweet(self, tweet_id: str) -> bool:
        """Cancel a scheduled tweet."""
        if tweet_id in self.scheduled_tweets:
            self.scheduled_tweets[tweet_id].status = ScheduleStatus.CANCELLED
            self._save_schedules()
            return True
        return False
    
    def get_scheduled_tweets(self, status: Optional[ScheduleStatus] = None) -> List[ScheduledTweet]:
        """Get scheduled tweets, optionally filtered by status."""
        if status:
            return [t for t in self.scheduled_tweets.values() if t.status == status]
        return list(self.scheduled_tweets.values())
    
    async def start(self) -> None:
        """Start the scheduler."""
        if self.running:
            return
        
        self.running = True
        self._task = asyncio.create_task(self._scheduler_loop())
        logging.info("Tweet scheduler started")
    
    async def stop(self) -> None:
        """Stop the scheduler."""
        self.running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logging.info("Tweet scheduler stopped")
    
    async def _scheduler_loop(self) -> None:
        """Main scheduler loop."""
        while self.running:
            try:
                await self._check_schedules()
                await asyncio.sleep(60)  # Check every minute
            except Exception as e:
                logging.error(f"Scheduler error: {e}")
                await asyncio.sleep(60)
    
    async def _check_schedules(self) -> None:
        """Check and execute due schedules."""
        now = datetime.utcnow()
        
        async with self._lock:
            for tweet in list(self.scheduled_tweets.values()):
                if tweet.status != ScheduleStatus.SCHEDULED:
                    continue
                
                next_run = tweet.get_next_run()
                if next_run and next_run <= now:
                    await self._execute_tweet(tweet)
    
    async def _execute_tweet(self, tweet: ScheduledTweet) -> None:
        """Execute a scheduled tweet."""
        try:
            success = await self.tweet_callback(
                content=tweet.content,
                media_urls=tweet.media_urls
            )
            
            if success:
                tweet.status = ScheduleStatus.POSTED
                tweet.posted_at = datetime.utcnow()
                logging.info(f"Tweet {tweet.id} posted successfully")
            else:
                raise Exception("Tweet callback returned False")
                
        except Exception as e:
            tweet.retry_count += 1
            if tweet.retry_count >= self.config.max_retries:
                tweet.status = ScheduleStatus.FAILED
                logging.error(f"Tweet {tweet.id} failed after {tweet.retry_count} retries")
            else:
                logging.warning(f"Tweet {tweet.id} failed, retry {tweet.retry_count}/{self.config.max_retries}")
        
        self._save_schedules()