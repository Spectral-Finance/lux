"""
youtube_community_prisms.community — spec-mandated prism classes for lux issue #70.

The issue's "Required class names & file paths" table (spec lines 293-303) names
the exact classes the lux monorepo expects. This module provides Python
equivalents of every one of them, built on the same production-grade substrate
as :mod:`youtube_community_prisms.prisms` (rate limiting, retry/backoff, event
emission, persistence, typed errors):

  * CommentManagementPrism        — commentThreads/comments read + moderation.
  * ResponseGenerationPrism       — automated reply generation + posting.
  * SentimentAnalysisPrism        — sentiment scoring over comments/threads.
  * SpamModerationPrism           — spam detection + moderation actions.
  * CommunityPostSchedulerPrism   — community post scheduling + queue.
  * EngagementCampaignPrism       — engagement campaign management.
  * CommentThreadsLens            — read lens over commentThreads.list.
  * CommunityManagementBeam       — orchestration beam tying prisms together.

Every class subclasses :class:`youtube_community_prisms.core.Prism`, so it
inherits the Lux-compatible ``handler(action, params, ctx)`` entry point that
returns ``{"ok": True, "data": ...}`` / ``{"ok": False, "error": ...}`` — the
Python analogue of Elixir's ``{:ok, _} | {:error, _}``.
"""

from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

from .analysis import analyze_sentiment, detect_spam, generate_response
from .core import Prism, ValidationError

__all__ = [
    "CommentManagementPrism",
    "ResponseGenerationPrism",
    "SentimentAnalysisPrism",
    "SpamModerationPrism",
    "CommunityPostSchedulerPrism",
    "EngagementCampaignPrism",
    "CommentThreadsLens",
    "CommunityManagementBeam",
]


def _now() -> float:
    return time.time()


# --------------------------------------------------------------------------- #
# CommentManagementPrism — commentThreads/comments read + moderation
# --------------------------------------------------------------------------- #
class CommentManagementPrism(Prism):
    """Comment management: list threads/comments, moderate, reply.

    Wraps the YouTube ``commentThreads`` and ``comments`` endpoints and adds
    sentiment/spam analysis plus moderation-status transitions.
    """

    name = "CommentManagement"

    MODERATION_STATUSES = ("heldForReview", "published", "rejected")

    def __init__(self, http, events=None, persistence=None,
                 banned_phrases: Optional[List[str]] = None) -> None:
        super().__init__(http, events=events, persistence=persistence)
        self.banned_phrases = banned_phrases

    # -- reading ----------------------------------------------------------- #
    def list_comment_threads(self, video_id: Optional[str] = None,
                             channel_id: Optional[str] = None,
                             max_results: int = 20,
                             order: str = "time",
                             page_token: Optional[str] = None
                             ) -> Dict[str, Any]:
        """List comment threads via ``commentThreads.list``."""
        params: Dict[str, Any] = {
            "part": "snippet,replies",
            "maxResults": max(1, min(100, max_results)),
            "order": order,
        }
        if video_id:
            params["videoId"] = video_id
        if channel_id:
            params["allThreadsRelatedToChannelId"] = channel_id
        if page_token:
            params["pageToken"] = page_token
        data = self.http.request("GET", "commentThreads", params=params)
        items = data.get("items", []) if isinstance(data, dict) else []
        self._emit("comment_threads_listed", count=len(items), video_id=video_id)
        return data

    def list_comments(self, parent_id: str, max_results: int = 20,
                      page_token: Optional[str] = None) -> Dict[str, Any]:
        """List replies/comments under a thread via ``comments.list``."""
        params: Dict[str, Any] = {
            "part": "snippet",
            "parentId": parent_id,
            "maxResults": max(1, min(100, max_results)),
        }
        if page_token:
            params["pageToken"] = page_token
        return self.http.request("GET", "comments", params=params)

    def get_comment_thread(self, thread_id: str) -> Dict[str, Any]:
        """Fetch a single comment thread by id."""
        data = self.http.request("GET", "commentThreads",
                                 params={"part": "snippet,replies", "id": thread_id})
        items = data.get("items", []) if isinstance(data, dict) else []
        if not items:
            raise ValidationError(f"comment thread {thread_id!r} not found")
        return items[0]

    # -- moderation -------------------------------------------------------- #
    def set_moderation_status(self, comment_id: str, status: str,
                              ban_user: bool = False) -> Dict[str, Any]:
        """Set a comment's moderation status via ``comments.setModerationStatus``."""
        if status not in self.MODERATION_STATUSES:
            raise ValidationError(
                f"status must be one of {self.MODERATION_STATUSES}")
        params = {"id": comment_id, "moderationStatus": status}
        if ban_user:
            params["banAuthor"] = "true"
        data = self.http.request("POST", "comments/setModerationStatus",
                                 params=params)
        self._emit("moderation_status_set", comment_id=comment_id,
                   status=status, ban_user=ban_user)
        return data or {"id": comment_id, "moderationStatus": status}

    def hold_for_review(self, comment_id: str) -> Dict[str, Any]:
        return self.set_moderation_status(comment_id, "heldForReview")

    def approve_comment(self, comment_id: str) -> Dict[str, Any]:
        return self.set_moderation_status(comment_id, "published")

    def reject_comment(self, comment_id: str, ban_user: bool = False
                       ) -> Dict[str, Any]:
        return self.set_moderation_status(comment_id, "rejected", ban_user=ban_user)

    def delete_comment(self, comment_id: str) -> Dict[str, Any]:
        """Delete a comment via ``comments.delete``."""
        data = self.http.request("DELETE", "comments", params={"id": comment_id})
        self._emit("comment_deleted", comment_id=comment_id)
        return data or {"id": comment_id, "deleted": True}

    def post_comment(self, video_id: str, text: str) -> Dict[str, Any]:
        """Post a top-level comment via ``commentThreads.insert``."""
        if not text or not text.strip():
            raise ValidationError("comment text must not be empty")
        body = {"snippet": {"videoId": video_id,
                            "topLevelComment": {"snippet": {"textOriginal": text}}}}
        data = self.http.request("POST", "commentThreads", json_body=body)
        self._emit("comment_posted", video_id=video_id,
                   comment_id=data.get("id") if isinstance(data, dict) else None)
        return data

    def update_comment(self, comment_id: str, text: str) -> Dict[str, Any]:
        """Update an existing comment's text via ``comments.update``."""
        if not text or not text.strip():
            raise ValidationError("comment text must not be empty")
        body = {"id": comment_id, "snippet": {"textOriginal": text}}
        data = self.http.request("PUT", "comments", json_body=body)
        self._emit("comment_updated", comment_id=comment_id)
        return data

    # -- analysis ---------------------------------------------------------- #
    def analyze_comment(self, text: str) -> Dict[str, Any]:
        """Return sentiment + spam verdict for a single comment body."""
        return {
            "sentiment": analyze_sentiment(text),
            "spam": detect_spam(text, banned_phrases=self.banned_phrases),
        }

    def analyze_thread(self, thread: Dict[str, Any]) -> Dict[str, Any]:
        """Analyse a full ``commentThreads`` item (top-level + replies)."""
        top = (thread.get("snippet", {})
               .get("topLevelComment", {})
               .get("snippet", {}))
        text = top.get("textDisplay", top.get("textOriginal", ""))
        result = self.analyze_comment(text)
        result["comment_id"] = (thread.get("snippet", {})
                                .get("topLevelComment", {})
                                .get("id"))
        result["video_id"] = thread.get("snippet", {}).get("videoId")
        result["author"] = top.get("authorDisplayName")
        return result

    def moderate_comment(self, comment_id: str, text: str,
                         auto: bool = True) -> Dict[str, Any]:
        """Analyse ``text`` and take a moderation action."""
        analysis = self.analyze_comment(text)
        spam_score = analysis["spam"]["score"]
        if auto and spam_score >= 0.5:
            action = self.hold_for_review(comment_id)
            decision = "held"
        else:
            action = self.approve_comment(comment_id)
            decision = "approved"
        self._emit("comment_moderated", comment_id=comment_id,
                   decision=decision, spam_score=spam_score)
        return {"analysis": analysis, "decision": decision, "action": action}


# --------------------------------------------------------------------------- #
# ResponseGenerationPrism — automated reply generation + posting
# --------------------------------------------------------------------------- #
class ResponseGenerationPrism(Prism):
    """Automated response generation for comments.

    Generates deterministic, template-based replies (no LLM required) and can
    post them via ``comments.insert``. Fully unit-testable offline.
    """

    name = "ResponseGeneration"

    def __init__(self, http, events=None, persistence=None,
                 creator_name: str = "the team") -> None:
        super().__init__(http, events=events, persistence=persistence)
        self.creator_name = creator_name

    def generate_reply(self, text: str, creator_name: Optional[str] = None,
                       include_emoji: bool = True) -> Dict[str, Any]:
        """Generate a suggested reply for ``text`` (deterministic)."""
        return generate_response(
            text,
            creator_name=creator_name or self.creator_name,
            include_emoji=include_emoji,
        )

    def generate_replies(self, comments: List[Dict[str, Any]]
                         ) -> List[Dict[str, Any]]:
        """Generate replies for a batch of comments.

        Each comment may be a raw string or a dict with a ``text`` key.
        """
        out: List[Dict[str, Any]] = []
        for c in comments:
            text = c if isinstance(c, str) else c.get("text", "")
            suggestion = self.generate_reply(text)
            suggestion["source_text"] = text
            out.append(suggestion)
        self._emit("replies_generated", count=len(out))
        return out

    def post_reply(self, parent_id: str, text: str) -> Dict[str, Any]:
        """Post a reply to a comment via ``comments.insert``."""
        if not text or not text.strip():
            raise ValidationError("reply text must not be empty")
        body = {"snippet": {"parentId": parent_id, "textOriginal": text}}
        data = self.http.request("POST", "comments", json_body=body)
        self._emit("reply_posted", parent_id=parent_id,
                   comment_id=data.get("id") if isinstance(data, dict) else None)
        return data

    def auto_reply(self, parent_id: str, text: str,
                   creator_name: Optional[str] = None) -> Dict[str, Any]:
        """Generate and post a reply in one step."""
        suggestion = self.generate_reply(text, creator_name=creator_name)
        posted = self.post_reply(parent_id, suggestion["reply"])
        return {"suggestion": suggestion, "posted": posted}

    def log_reply(self, parent_id: str, suggestion: Dict[str, Any]) -> None:
        """Persist a generated reply for auditing/analytics."""
        self.persistence.set(f"reply:{parent_id}", suggestion)
        self._emit("reply_logged", parent_id=parent_id)

    def reply_log(self) -> List[Dict[str, Any]]:
        return [v for k, v in self.persistence.all().items()
                if k.startswith("reply:")]


# --------------------------------------------------------------------------- #
# SentimentAnalysisPrism — sentiment scoring over comments/threads
# --------------------------------------------------------------------------- #
class SentimentAnalysisPrism(Prism):
    """Sentiment analysis over comments and comment threads."""

    name = "SentimentAnalysis"

    def analyze_text(self, text: str) -> Dict[str, Any]:
        """Return the sentiment analysis for a single piece of text."""
        return analyze_sentiment(text)

    def analyze_comment(self, comment: Dict[str, Any]) -> Dict[str, Any]:
        """Analyse a comment dict (or raw string) for sentiment."""
        text = comment if isinstance(comment, str) else comment.get(
            "text", comment.get("textDisplay", ""))
        result = analyze_sentiment(text)
        if isinstance(comment, dict):
            result["comment_id"] = comment.get("id") or comment.get("comment_id")
            result["author"] = comment.get("author") or comment.get(
                "authorDisplayName")
        return result

    def analyze_thread(self, thread: Dict[str, Any]) -> Dict[str, Any]:
        """Analyse a ``commentThreads`` item's top-level comment."""
        top = (thread.get("snippet", {})
               .get("topLevelComment", {})
               .get("snippet", {}))
        text = top.get("textDisplay", top.get("textOriginal", ""))
        result = analyze_sentiment(text)
        result["comment_id"] = (thread.get("snippet", {})
                                .get("topLevelComment", {})
                                .get("id"))
        result["video_id"] = thread.get("snippet", {}).get("videoId")
        return result

    def analyze_batch(self, texts: List[str]) -> Dict[str, Any]:
        """Aggregate sentiment over a batch of texts."""
        counts = {"positive": 0, "negative": 0, "neutral": 0}
        score_sum = 0.0
        for t in texts:
            s = analyze_sentiment(t)
            counts[s["label"]] += 1
            score_sum += s["score"]
        total = len(texts)
        return {
            "count": total,
            "counts": counts,
            "avg_score": round(score_sum / total, 4) if total else 0.0,
            "distribution": {
                k: round(100.0 * v / total, 2) if total else 0.0
                for k, v in counts.items()
            },
        }

    def analyze_threads(self, threads: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Aggregate sentiment over a list of comment threads."""
        texts = []
        for t in threads:
            top = (t.get("snippet", {})
                   .get("topLevelComment", {})
                   .get("snippet", {}))
            texts.append(top.get("textDisplay", top.get("textOriginal", "")))
        return self.analyze_batch(texts)


# --------------------------------------------------------------------------- #
# SpamModerationPrism — spam detection + moderation actions
# --------------------------------------------------------------------------- #
class SpamModerationPrism(Prism):
    """Spam detection and moderation.

    Scores comments for spam likelihood and takes moderation actions
    (hold / approve / reject) based on configurable thresholds.
    """

    name = "SpamModeration"

    def __init__(self, http, events=None, persistence=None,
                 banned_phrases: Optional[List[str]] = None,
                 spam_threshold: float = 0.5) -> None:
        super().__init__(http, events=events, persistence=persistence)
        self.banned_phrases = banned_phrases
        self.spam_threshold = spam_threshold

    def detect_spam(self, text: str) -> Dict[str, Any]:
        """Score ``text`` for spam likelihood."""
        return detect_spam(text, banned_phrases=self.banned_phrases)

    def is_spam(self, text: str) -> bool:
        """Return True if ``text`` scores at or above the spam threshold."""
        return self.detect_spam(text)["score"] >= self.spam_threshold

    def moderate(self, comment_id: str, text: str,
                 auto: bool = True) -> Dict[str, Any]:
        """Detect spam and take a moderation action.

        When ``auto`` is true, spam at/above ``spam_threshold`` is held for
        review; otherwise the comment is approved.
        """
        spam = self.detect_spam(text)
        if auto and spam["score"] >= self.spam_threshold:
            action = self._set_status(comment_id, "heldForReview")
            decision = "held"
        else:
            action = self._set_status(comment_id, "published")
            decision = "approved"
        self._emit("spam_moderated", comment_id=comment_id,
                   decision=decision, spam_score=spam["score"])
        return {"spam": spam, "decision": decision, "action": action}

    def _set_status(self, comment_id: str, status: str) -> Dict[str, Any]:
        data = self.http.request("POST", "comments/setModerationStatus",
                                 params={"id": comment_id,
                                         "moderationStatus": status})
        return data or {"id": comment_id, "moderationStatus": status}

    def hold(self, comment_id: str) -> Dict[str, Any]:
        return self._set_status(comment_id, "heldForReview")

    def approve(self, comment_id: str) -> Dict[str, Any]:
        return self._set_status(comment_id, "published")

    def reject(self, comment_id: str, ban_user: bool = False) -> Dict[str, Any]:
        params = {"id": comment_id, "moderationStatus": "rejected"}
        if ban_user:
            params["banAuthor"] = "true"
        data = self.http.request("POST", "comments/setModerationStatus",
                                 params=params)
        self._emit("spam_rejected", comment_id=comment_id, ban_user=ban_user)
        return data or {"id": comment_id, "moderationStatus": "rejected"}

    def log_detection(self, comment_id: str, result: Dict[str, Any]) -> None:
        """Persist a spam-detection record for auditing."""
        self.persistence.set(f"spam:{comment_id}", result)
        self._emit("spam_logged", comment_id=comment_id)

    def detection_log(self) -> List[Dict[str, Any]]:
        return [v for k, v in self.persistence.all().items()
                if k.startswith("spam:")]


# --------------------------------------------------------------------------- #
# CommunityPostSchedulerPrism — community post scheduling + queue
# --------------------------------------------------------------------------- #
class CommunityPostSchedulerPrism(Prism):
    """Community post scheduling and queue management.

    YouTube does not expose a public community-post write endpoint in the Data
    API, so this prism models scheduling/queue semantics locally (persisted)
    and, when a ``publisher`` callable is supplied, delegates the actual publish.
    """

    name = "CommunityPostScheduler"

    def __init__(self, http, events=None, persistence=None,
                 publisher=None) -> None:
        super().__init__(http, events=events, persistence=persistence)
        self.publisher = publisher

    @staticmethod
    def _next_id(prefix: str) -> str:
        return f"{prefix}_{int(time.time() * 1000)}_{id(object()) & 0xffffff:x}"

    def schedule_post(self, channel_id: str, content: str,
                      scheduled_for: float,
                      post_type: str = "text",
                      metadata: Optional[Dict[str, Any]] = None
                      ) -> Dict[str, Any]:
        """Schedule a community post for future publication."""
        if not content or not content.strip():
            raise ValidationError("post content must not be empty")
        if scheduled_for <= 0:
            raise ValidationError("scheduled_for must be a positive epoch")
        post = {
            "id": self._next_id("post"),
            "channel_id": channel_id,
            "content": content,
            "post_type": post_type,
            "scheduled_for": scheduled_for,
            "status": "scheduled",
            "created_at": _now(),
            "metadata": metadata or {},
        }
        self.persistence.set(f"community_post:{post['id']}", post)
        self._emit("post_scheduled", post_id=post["id"],
                   channel_id=channel_id, scheduled_for=scheduled_for)
        return post

    def publish_now(self, channel_id: str, content: str,
                    post_type: str = "text",
                    metadata: Optional[Dict[str, Any]] = None
                    ) -> Dict[str, Any]:
        """Publish a community post immediately (or via the injected publisher)."""
        if not content or not content.strip():
            raise ValidationError("post content must not be empty")
        post = {
            "id": self._next_id("post"),
            "channel_id": channel_id,
            "content": content,
            "post_type": post_type,
            "scheduled_for": _now(),
            "status": "publishing",
            "created_at": _now(),
            "metadata": metadata or {},
        }
        result = None
        if self.publisher is not None:
            result = self.publisher(channel_id, post)
            post["status"] = "published"
            post["publisher_result"] = result
        else:
            post["status"] = "published"
        self.persistence.set(f"community_post:{post['id']}", post)
        self._emit("post_published", post_id=post["id"], channel_id=channel_id)
        return post

    def get_post(self, post_id: str) -> Dict[str, Any]:
        post = self.persistence.get(f"community_post:{post_id}")
        if post is None:
            raise ValidationError(f"unknown post {post_id!r}")
        return post

    def list_posts(self, channel_id: Optional[str] = None,
                   status: Optional[str] = None) -> List[Dict[str, Any]]:
        out = [v for k, v in self.persistence.all().items()
               if k.startswith("community_post:")]
        if channel_id is not None:
            out = [p for p in out if p.get("channel_id") == channel_id]
        if status is not None:
            out = [p for p in out if p.get("status") == status]
        return out

    def cancel_post(self, post_id: str) -> Dict[str, Any]:
        post = self.get_post(post_id)
        if post.get("status") == "published":
            raise ValidationError("cannot cancel an already-published post")
        post["status"] = "cancelled"
        self.persistence.set(f"community_post:{post_id}", post)
        self._emit("post_cancelled", post_id=post_id)
        return post

    def process_due_posts(self, now: Optional[float] = None) -> List[Dict[str, Any]]:
        """Publish all scheduled posts whose ``scheduled_for`` has passed."""
        now = now if now is not None else _now()
        published: List[Dict[str, Any]] = []
        for post in self.list_posts(status="scheduled"):
            if post["scheduled_for"] <= now:
                published.append(self.publish_now(
                    post["channel_id"], post["content"],
                    post_type=post.get("post_type", "text"),
                    metadata=post.get("metadata")))
        return published

    def queue_depth(self, channel_id: Optional[str] = None) -> int:
        return len(self.list_posts(channel_id=channel_id, status="scheduled"))


# --------------------------------------------------------------------------- #
# EngagementCampaignPrism — engagement campaign management
# --------------------------------------------------------------------------- #
class EngagementCampaignPrism(Prism):
    """Engagement campaign management: create, track metrics, report, close."""

    name = "EngagementCampaign"

    def create_campaign(self, name: str, channel_id: str,
                        goals: Optional[Dict[str, Any]] = None,
                        start: Optional[float] = None,
                        end: Optional[float] = None) -> Dict[str, Any]:
        """Create an engagement campaign record."""
        campaign = {
            "id": f"campaign_{int(_now() * 1000)}",
            "name": name,
            "channel_id": channel_id,
            "goals": goals or {},
            "start": start or _now(),
            "end": end,
            "status": "active",
            "metrics": {},
        }
        self.persistence.set(f"campaign:{campaign['id']}", campaign)
        self._emit("campaign_created", campaign_id=campaign["id"], name=name)
        return campaign

    def record_metric(self, campaign_id: str, metric: str,
                      value: float) -> Dict[str, Any]:
        """Attach a metric observation to a campaign."""
        camp = self.persistence.get(f"campaign:{campaign_id}")
        if camp is None:
            raise ValidationError(f"unknown campaign {campaign_id!r}")
        camp.setdefault("metrics", {})
        camp["metrics"].setdefault(metric, []).append(
            {"value": value, "at": _now()})
        self.persistence.set(f"campaign:{campaign_id}", camp)
        self._emit("campaign_metric_recorded", campaign_id=campaign_id,
                   metric=metric, value=value)
        return camp

    def campaign_report(self, campaign_id: str) -> Dict[str, Any]:
        """Summarise a campaign's recorded metrics."""
        camp = self.persistence.get(f"campaign:{campaign_id}")
        if camp is None:
            raise ValidationError(f"unknown campaign {campaign_id!r}")
        summary: Dict[str, Any] = {}
        for metric, obs in camp.get("metrics", {}).items():
            values = [o["value"] for o in obs]
            summary[metric] = {
                "count": len(values),
                "sum": round(sum(values), 4),
                "avg": round(sum(values) / len(values), 4) if values else 0.0,
                "min": min(values) if values else None,
                "max": max(values) if values else None,
            }
        return {"campaign_id": campaign_id, "name": camp.get("name"),
                "status": camp.get("status"), "metrics": summary}

    def close_campaign(self, campaign_id: str) -> Dict[str, Any]:
        camp = self.persistence.get(f"campaign:{campaign_id}")
        if camp is None:
            raise ValidationError(f"unknown campaign {campaign_id!r}")
        camp["status"] = "closed"
        camp["closed_at"] = _now()
        self.persistence.set(f"campaign:{campaign_id}", camp)
        self._emit("campaign_closed", campaign_id=campaign_id)
        return camp

    def list_campaigns(self, channel_id: Optional[str] = None,
                       status: Optional[str] = None) -> List[Dict[str, Any]]:
        out = [v for k, v in self.persistence.all().items()
               if k.startswith("campaign:")]
        if channel_id is not None:
            out = [c for c in out if c.get("channel_id") == channel_id]
        if status is not None:
            out = [c for c in out if c.get("status") == status]
        return out


# --------------------------------------------------------------------------- #
# CommentThreadsLens — read lens over commentThreads.list
# --------------------------------------------------------------------------- #
class CommentThreadsLens(Prism):
    """Read lens over ``commentThreads.list``.

    A lens is a read-only query helper: it fetches comment threads and
    normalises them into a flat, easy-to-consume shape for analytics or
    moderation pipelines.
    """

    name = "CommentThreadsLens"

    def fetch(self, video_id: Optional[str] = None,
              channel_id: Optional[str] = None,
              max_results: int = 20,
              order: str = "time",
              page_token: Optional[str] = None) -> Dict[str, Any]:
        """Fetch raw ``commentThreads.list`` response."""
        params: Dict[str, Any] = {
            "part": "snippet,replies",
            "maxResults": max(1, min(100, max_results)),
            "order": order,
        }
        if video_id:
            params["videoId"] = video_id
        if channel_id:
            params["allThreadsRelatedToChannelId"] = channel_id
        if page_token:
            params["pageToken"] = page_token
        return self.http.request("GET", "commentThreads", params=params)

    def normalize(self, response: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Flatten a ``commentThreads.list`` response into comment dicts."""
        out: List[Dict[str, Any]] = []
        for item in response.get("items", []):
            snippet = item.get("snippet", {})
            top = snippet.get("topLevelComment", {})
            top_snip = top.get("snippet", {})
            out.append({
                "thread_id": item.get("id"),
                "comment_id": top.get("id"),
                "video_id": snippet.get("videoId"),
                "author": top_snip.get("authorDisplayName"),
                "text": top_snip.get("textDisplay", top_snip.get("textOriginal", "")),
                "like_count": top_snip.get("likeCount", 0),
                "reply_count": len(snippet.get("replies", {}).get("comments", []) or []),
                "published_at": top_snip.get("publishedAt"),
            })
        return out

    def get(self, video_id: Optional[str] = None,
            channel_id: Optional[str] = None,
            max_results: int = 20) -> List[Dict[str, Any]]:
        """Fetch and normalise in one call."""
        return self.normalize(self.fetch(video_id=video_id,
                                         channel_id=channel_id,
                                         max_results=max_results))


# --------------------------------------------------------------------------- #
# CommunityManagementBeam — orchestration beam tying prisms together
# --------------------------------------------------------------------------- #
class CommunityManagementBeam(Prism):
    """Orchestration beam for the full community-management workflow.

    Composes the other prisms into a single entry point that can, for example,
    fetch threads, analyse sentiment + spam, auto-moderate, and generate
    replies — the end-to-end "comment management + moderation" workflow the
    issue's integration test requires.
    """

    name = "CommunityManagementBeam"

    def __init__(self, http, events=None, persistence=None,
                 banned_phrases: Optional[List[str]] = None,
                 creator_name: str = "the team") -> None:
        super().__init__(http, events=events, persistence=persistence)
        self.comments = CommentManagementPrism(
            http, events=self.events, persistence=self.persistence,
            banned_phrases=banned_phrases)
        self.responses = ResponseGenerationPrism(
            http, events=self.events, persistence=self.persistence,
            creator_name=creator_name)
        self.sentiment = SentimentAnalysisPrism(
            http, events=self.events, persistence=self.persistence)
        self.spam = SpamModerationPrism(
            http, events=self.events, persistence=self.persistence,
            banned_phrases=banned_phrases)
        self.posts = CommunityPostSchedulerPrism(
            http, events=self.events, persistence=self.persistence)
        self.campaigns = EngagementCampaignPrism(
            http, events=self.events, persistence=self.persistence)
        self.lens = CommentThreadsLens(
            http, events=self.events, persistence=self.persistence)

    def triage_threads(self, video_id: Optional[str] = None,
                       channel_id: Optional[str] = None,
                       max_results: int = 20,
                       auto_moderate: bool = True) -> Dict[str, Any]:
        """Fetch threads, analyse sentiment + spam, optionally auto-moderate.

        Returns a per-thread triage report plus aggregate counts. This is the
        end-to-end workflow demonstrated by the integration test.
        """
        response = self.lens.fetch(video_id=video_id, channel_id=channel_id,
                                   max_results=max_results)
        threads = response.get("items", []) if isinstance(response, dict) else []
        report: List[Dict[str, Any]] = []
        counts = {"held": 0, "approved": 0, "spam": 0}
        for t in threads:
            analysis = self.comments.analyze_thread(t)
            entry = {
                "comment_id": analysis.get("comment_id"),
                "video_id": analysis.get("video_id"),
                "author": analysis.get("author"),
                "sentiment": analysis["sentiment"],
                "spam": analysis["spam"],
            }
            if auto_moderate and analysis.get("comment_id"):
                spam_score = analysis["spam"]["score"]
                if spam_score >= 0.5:
                    self.spam.hold(analysis["comment_id"])
                    entry["decision"] = "held"
                    counts["held"] += 1
                    counts["spam"] += 1
                else:
                    self.spam.approve(analysis["comment_id"])
                    entry["decision"] = "approved"
                    counts["approved"] += 1
            report.append(entry)
        self._emit("triage_complete", thread_count=len(report), counts=counts)
        return {"threads": report, "counts": counts,
                "total": len(report)}