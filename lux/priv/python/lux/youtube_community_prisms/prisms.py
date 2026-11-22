"""
youtube_community_prisms.prisms — the five prisms required by lux issue #70
(YouTube Community Management and Engagement).

Each prism subclasses :class:`youtube_community_prisms.core.Prism` and
implements the features listed in the issue's acceptance criteria:

  * CommunityPostPrism      — community post scheduling + publishing + queue.
  * CommentModerationPrism  — comment listing, sentiment, spam detection,
                              moderation status, automated responses.
  * LiveChatPrism           — live chat message listing/moderation, slow mode,
                              live chat bans, message persistence.
  * MemberManagementPrism   — subscriber/member interaction tracking, fan
                              segmentation, interaction patterns.
  * AnalyticsPrism          — engagement analytics, sentiment aggregation,
                              campaign metrics, reporting.

Every operation:
  * goes through the shared rate-limited / retrying HTTP core,
  * emits a structured event via the shared EventEmitter,
  * persists state via the shared persistence hook where relevant.
"""

from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

from .analysis import analyze_sentiment, detect_spam, generate_response
from .core import Prism, ValidationError

__all__ = [
    "CommunityPostPrism",
    "CommentModerationPrism",
    "LiveChatPrism",
    "MemberManagementPrism",
    "AnalyticsPrism",
]


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _now() -> float:
    return time.time()


def _chunks(seq: List[Any], n: int) -> List[List[Any]]:
    return [seq[i:i + n] for i in range(0, len(seq), n)]


# --------------------------------------------------------------------------- #
# 1. CommunityPostPrism
# --------------------------------------------------------------------------- #
class CommunityPostPrism(Prism):
    """Community post scheduling, publishing and queue management.

    YouTube does not expose a public community-post write endpoint in the Data
    API, so this prism models the *scheduling* and *queue* semantics locally
    (persisted) and, when a ``publisher`` callable is supplied, delegates the
    actual publish to it. This keeps the prism fully testable offline while
    remaining drop-in usable with a real publisher in production.
    """

    name = "CommunityPost"

    def __init__(self, http, events=None, persistence=None,
                 publisher=None) -> None:
        super().__init__(http, events=events, persistence=persistence)
        #: Optional ``fn(channel_id, post) -> dict`` that performs the real
        #: publish (e.g. a YouTube-side integration). When ``None`` the post is
        #: only queued/persisted.
        self.publisher = publisher

    # -- scheduling -------------------------------------------------------- #
    def schedule_post(self, channel_id: str, content: str,
                      scheduled_for: float,
                      post_type: str = "text",
                      metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Schedule a community post for future publication.

        ``scheduled_for`` is a POSIX epoch timestamp. Returns the stored post
        record (with a generated ``id`` and ``status="scheduled"``).
        """
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
                    metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
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
            if isinstance(result, dict):
                post.update(result)
        post["status"] = "published"
        post["published_at"] = _now()
        self.persistence.set(f"community_post:{post['id']}", post)
        self._emit("post_published", post_id=post["id"], channel_id=channel_id)
        return post

    def cancel_post(self, post_id: str) -> Dict[str, Any]:
        """Cancel a scheduled post."""
        post = self.persistence.get(f"community_post:{post_id}")
        if post is None:
            raise ValidationError(f"unknown post {post_id!r}")
        post["status"] = "cancelled"
        self.persistence.set(f"community_post:{post_id}", post)
        self._emit("post_cancelled", post_id=post_id)
        return post

    # -- queue processing -------------------------------------------------- #
    def due_posts(self, now: Optional[float] = None) -> List[Dict[str, Any]]:
        """Return scheduled posts whose ``scheduled_for`` has passed."""
        now = now if now is not None else _now()
        due = []
        for key, post in self.persistence.all().items():
            if (key.startswith("community_post:")
                    and post.get("status") == "scheduled"
                    and post.get("scheduled_for", 0) <= now):
                due.append(post)
        due.sort(key=lambda p: p.get("scheduled_for", 0))
        return due

    def process_due_posts(self, now: Optional[float] = None) -> List[Dict[str, Any]]:
        """Publish every due scheduled post; return the published records."""
        published = []
        for post in self.due_posts(now=now):
            published.append(self.publish_now(
                post["channel_id"], post["content"],
                post_type=post.get("post_type", "text"),
                metadata=post.get("metadata")))
        return published

    def list_posts(self, channel_id: Optional[str] = None,
                   status: Optional[str] = None) -> List[Dict[str, Any]]:
        """List persisted posts, optionally filtered by channel and status."""
        out = []
        for key, post in self.persistence.all().items():
            if not key.startswith("community_post:"):
                continue
            if channel_id is not None and post.get("channel_id") != channel_id:
                continue
            if status is not None and post.get("status") != status:
                continue
            out.append(post)
        out.sort(key=lambda p: p.get("created_at", 0))
        return out

    def get_post(self, post_id: str) -> Dict[str, Any]:
        post = self.persistence.get(f"community_post:{post_id}")
        if post is None:
            raise ValidationError(f"unknown post {post_id!r}")
        return post

    @staticmethod
    def _next_id(prefix: str) -> str:
        return f"{prefix}_{int(time.time() * 1000)}_{id(object()) & 0xffffff:x}"


# --------------------------------------------------------------------------- #
# 2. CommentModerationPrism
# --------------------------------------------------------------------------- #
class CommentModerationPrism(Prism):
    """Comment listing, sentiment analysis, spam detection, moderation and
    automated response generation."""

    name = "CommentModeration"

    #: YouTube moderation statuses.
    MODERATION_STATUSES = ("heldForReview", "published", "rejected")

    def __init__(self, http, events=None, persistence=None,
                 banned_phrases: Optional[List[str]] = None,
                 auto_hold_threshold: float = 0.5) -> None:
        super().__init__(http, events=events, persistence=persistence)
        self.banned_phrases = banned_phrases
        self.auto_hold_threshold = auto_hold_threshold

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
        self._emit("comment_threads_listed",
                   count=len(items), video_id=video_id)
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

    # -- analysis ---------------------------------------------------------- #
    def analyze_comment(self, text: str) -> Dict[str, Any]:
        """Return sentiment + spam verdict for a single comment body."""
        sentiment = analyze_sentiment(text)
        spam = detect_spam(text, banned_phrases=self.banned_phrases)
        return {"sentiment": sentiment, "spam": spam}

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

    # -- moderation -------------------------------------------------------- #
    def set_moderation_status(self, comment_id: str, status: str,
                              ban_user: bool = False) -> Dict[str, Any]:
        """Set a comment's moderation status via ``comments.setModerationStatus``.

        ``status`` must be one of ``heldForReview`` / ``published`` /
        ``rejected``. ``ban_user`` additionally blocks the author.
        """
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

    def moderate_comment(self, comment_id: str, text: str,
                         auto: bool = True) -> Dict[str, Any]:
        """Analyse ``text`` and take a moderation action.

        When ``auto`` is true, spam above ``auto_hold_threshold`` is held for
        review; otherwise the comment is approved. Returns the analysis plus
        the action taken.
        """
        analysis = self.analyze_comment(text)
        spam_score = analysis["spam"]["score"]
        if auto and spam_score >= self.auto_hold_threshold:
            action = self.hold_for_review(comment_id)
            decision = "held"
        else:
            action = self.approve_comment(comment_id)
            decision = "approved"
        self._emit("comment_moderated", comment_id=comment_id,
                   decision=decision, spam_score=spam_score)
        return {"analysis": analysis, "decision": decision, "action": action}

    # -- response generation ---------------------------------------------- #
    def generate_reply(self, text: str, creator_name: str = "the team"
                       ) -> Dict[str, Any]:
        """Generate a suggested reply for ``text`` (no LLM, deterministic)."""
        return generate_response(text, creator_name=creator_name)

    def post_reply(self, parent_id: str, text: str) -> Dict[str, Any]:
        """Post a reply to a comment via ``comments.insert``."""
        body = {"snippet": {"parentId": parent_id, "textOriginal": text}}
        data = self.http.request("POST", "comments", json_body=body)
        self._emit("reply_posted", parent_id=parent_id,
                   comment_id=data.get("id") if isinstance(data, dict) else None)
        return data

    def auto_reply(self, parent_id: str, text: str,
                   creator_name: str = "the team") -> Dict[str, Any]:
        """Generate and post a reply in one step."""
        suggestion = self.generate_reply(text, creator_name=creator_name)
        posted = self.post_reply(parent_id, suggestion["reply"])
        return {"suggestion": suggestion, "posted": posted}

    # -- persistence of moderation log ------------------------------------ #
    def log_moderation(self, comment_id: str, record: Dict[str, Any]) -> None:
        """Persist a moderation record for auditing/analytics."""
        self.persistence.set(f"moderation:{comment_id}", record)
        self._emit("moderation_logged", comment_id=comment_id)

    def moderation_log(self) -> List[Dict[str, Any]]:
        return [v for k, v in self.persistence.all().items()
                if k.startswith("moderation:")]


# --------------------------------------------------------------------------- #
# 3. LiveChatPrism
# --------------------------------------------------------------------------- #
class LiveChatPrism(Prism):
    """Live chat message listing, moderation, slow-mode and live-chat bans."""

    name = "LiveChat"

    def list_messages(self, live_chat_id: str, max_results: int = 50,
                      page_token: Optional[str] = None) -> Dict[str, Any]:
        """List live chat messages via ``liveChatMessages.list``."""
        params: Dict[str, Any] = {
            "liveChatId": live_chat_id,
            "part": "snippet,authorDetails",
            "maxResults": max(1, min(200, max_results)),
        }
        if page_token:
            params["pageToken"] = page_token
        data = self.http.request("GET", "liveChatMessages", params=params)
        items = data.get("items", []) if isinstance(data, dict) else []
        self._emit("live_chat_listed", live_chat_id=live_chat_id,
                   count=len(items))
        return data

    def _message_text(self, item: Dict[str, Any]) -> str:
        return (item.get("snippet", {})
                .get("displayMessage", ""))

    def moderate_message(self, live_chat_id: str, message_id: str,
                         text: Optional[str] = None) -> Dict[str, Any]:
        """Analyse a live-chat message and delete it if it looks like spam."""
        analysis = self.analyze_comment(text) if text else None
        deleted = False
        if analysis and analysis["spam"]["spam"]:
            self.delete_message(live_chat_id, message_id)
            deleted = True
        self._emit("live_chat_moderated", message_id=message_id,
                   deleted=deleted,
                   spam_score=analysis["spam"]["score"] if analysis else None)
        return {"message_id": message_id, "deleted": deleted,
                "analysis": analysis}

    def delete_message(self, live_chat_id: str, message_id: str) -> Dict[str, Any]:
        """Delete a live chat message (moderation)."""
        data = self.http.request("DELETE", "liveChatMessages",
                                 params={"id": message_id})
        self._emit("live_chat_message_deleted", message_id=message_id,
                   live_chat_id=live_chat_id)
        return data or {"id": message_id, "deleted": True}

    def ban_user(self, live_chat_id: str, channel_id: str,
                 banned_user_id: str, ban_duration_seconds: int = 300
                 ) -> Dict[str, Any]:
        """Ban a user from live chat via ``liveChatMessages.ban``."""
        if ban_duration_seconds <= 0:
            raise ValidationError("ban_duration_seconds must be positive")
        body = {
            "snippet": {
                "liveChatId": live_chat_id,
                "type": "liveChatBan",
                "banDurationSeconds": ban_duration_seconds,
                "bannedUserDetails": {"channelId": banned_user_id},
            }
        }
        data = self.http.request("POST", "liveChatMessages/ban",
                                 json_body=body)
        self._emit("live_chat_user_banned", banned_user_id=banned_user_id,
                   live_chat_id=live_chat_id,
                   duration=ban_duration_seconds)
        return data or {"banned": banned_user_id}

    def set_slow_mode(self, live_chat_id: str, slow_mode_seconds: int
                      ) -> Dict[str, Any]:
        """Enable/disable slow mode (0 disables) via ``liveChatModerators``-
        style local state + emit. YouTube exposes this through the owner UI;
        we persist the setting and emit an event for downstream integration."""
        if slow_mode_seconds < 0:
            raise ValidationError("slow_mode_seconds must be >= 0")
        self.persistence.set(f"slow_mode:{live_chat_id}",
                             {"live_chat_id": live_chat_id,
                              "slow_mode_seconds": slow_mode_seconds,
                              "updated_at": _now()})
        self._emit("slow_mode_set", live_chat_id=live_chat_id,
                   slow_mode_seconds=slow_mode_seconds)
        return {"live_chat_id": live_chat_id,
                "slow_mode_seconds": slow_mode_seconds}

    def get_slow_mode(self, live_chat_id: str) -> int:
        rec = self.persistence.get(f"slow_mode:{live_chat_id}", {})
        return int(rec.get("slow_mode_seconds", 0))

    # -- persistence of chat log ------------------------------------------ #
    def log_message(self, live_chat_id: str, item: Dict[str, Any]) -> None:
        """Persist a live-chat message for later analytics."""
        self.persistence.set(f"live_chat:{item.get('id')}",
                             {"live_chat_id": live_chat_id, **item})
        self._emit("live_chat_message_logged", message_id=item.get("id"))

    def message_log(self, live_chat_id: Optional[str] = None
                    ) -> List[Dict[str, Any]]:
        out = [v for k, v in self.persistence.all().items()
               if k.startswith("live_chat:")]
        if live_chat_id is not None:
            out = [m for m in out if m.get("live_chat_id") == live_chat_id]
        return out

    # reuse analysis helper from CommentModerationPrism without duplication
    @staticmethod
    def analyze_comment(text: str) -> Dict[str, Any]:
        return {"sentiment": analyze_sentiment(text),
                "spam": detect_spam(text)}


# --------------------------------------------------------------------------- #
# 4. MemberManagementPrism
# --------------------------------------------------------------------------- #
class MemberManagementPrism(Prism):
    """Subscriber / member interaction tracking and fan segmentation."""

    name = "MemberManagement"

    def __init__(self, http, events=None, persistence=None) -> None:
        super().__init__(http, events=events, persistence=persistence)

    # -- interaction tracking --------------------------------------------- #
    def record_interaction(self, channel_id: str, user_id: str,
                           interaction_type: str,
                           weight: float = 1.0,
                           metadata: Optional[Dict[str, Any]] = None
                           ) -> Dict[str, Any]:
        """Record an interaction (comment/like/post_reply/...) for a user."""
        if not user_id:
            raise ValidationError("user_id is required")
        key = f"member:{channel_id}:{user_id}"
        rec = self.persistence.get(key, {
            "channel_id": channel_id, "user_id": user_id,
            "interactions": [], "score": 0.0, "first_seen": _now(),
        })
        entry = {
            "type": interaction_type,
            "weight": weight,
            "at": _now(),
            "metadata": metadata or {},
        }
        rec["interactions"].append(entry)
        rec["score"] = round(rec.get("score", 0.0) + weight, 4)
        rec["last_seen"] = entry["at"]
        self.persistence.set(key, rec)
        self._emit("interaction_recorded", channel_id=channel_id,
                   user_id=user_id, interaction_type=interaction_type,
                   weight=weight)
        return rec

    def get_member(self, channel_id: str, user_id: str) -> Dict[str, Any]:
        rec = self.persistence.get(f"member:{channel_id}:{user_id}")
        if rec is None:
            raise ValidationError(f"unknown member {user_id!r}")
        return rec

    def list_members(self, channel_id: str) -> List[Dict[str, Any]]:
        return [v for k, v in self.persistence.all().items()
                if k.startswith(f"member:{channel_id}:")]

    # -- segmentation ------------------------------------------------------ #
    def segment_members(self, channel_id: str,
                        thresholds: Optional[Dict[str, float]] = None
                        ) -> Dict[str, List[Dict[str, Any]]]:
        """Bucket members into segments by interaction score.

        Default thresholds: ``active`` >= 10, ``engaged`` >= 3, else ``new``.
        """
        thresholds = thresholds or {"active": 10.0, "engaged": 3.0}
        segments: Dict[str, List[Dict[str, Any]]] = {
            "active": [], "engaged": [], "new": []}
        for m in self.list_members(channel_id):
            score = m.get("score", 0.0)
            if score >= thresholds["active"]:
                segments["active"].append(m)
            elif score >= thresholds["engaged"]:
                segments["engaged"].append(m)
            else:
                segments["new"].append(m)
        self._emit("members_segmented", channel_id=channel_id,
                   counts={k: len(v) for k, v in segments.items()})
        return segments

    def interaction_patterns(self, channel_id: str) -> Dict[str, Any]:
        """Aggregate interaction patterns for a channel's members."""
        members = self.list_members(channel_id)
        by_type: Dict[str, int] = {}
        total_score = 0.0
        for m in members:
            total_score += m.get("score", 0.0)
            for it in m.get("interactions", []):
                by_type[it["type"]] = by_type.get(it["type"], 0) + 1
        return {
            "channel_id": channel_id,
            "member_count": len(members),
            "total_score": round(total_score, 4),
            "avg_score": round(total_score / len(members), 4) if members else 0.0,
            "by_type": by_type,
        }

    def top_members(self, channel_id: str, limit: int = 10
                    ) -> List[Dict[str, Any]]:
        members = sorted(self.list_members(channel_id),
                         key=lambda m: m.get("score", 0.0), reverse=True)
        return members[:max(1, limit)]


# --------------------------------------------------------------------------- #
# 5. AnalyticsPrism
# --------------------------------------------------------------------------- #
class AnalyticsPrism(Prism):
    """Engagement analytics, sentiment aggregation and campaign metrics."""

    name = "Analytics"

    def __init__(self, http, events=None, persistence=None) -> None:
        super().__init__(http, events=events, persistence=persistence)

    # -- comment analytics ------------------------------------------------- #
    def engagement_summary(self, threads: List[Dict[str, Any]]
                           ) -> Dict[str, Any]:
        """Compute engagement metrics over a list of comment threads."""
        total = len(threads)
        likes = 0
        replies = 0
        sentiment_counts = {"positive": 0, "negative": 0, "neutral": 0}
        score_sum = 0.0
        for t in threads:
            snippet = t.get("snippet", {})
            top = snippet.get("topLevelComment", {}).get("snippet", {})
            likes += int(top.get("likeCount", 0) or 0)
            replies += len(snippet.get("replies", {}).get("comments", []) or [])
            text = top.get("textDisplay", top.get("textOriginal", ""))
            s = analyze_sentiment(text)
            sentiment_counts[s["label"]] += 1
            score_sum += s["score"]
        return {
            "thread_count": total,
            "total_likes": likes,
            "total_replies": replies,
            "avg_likes_per_thread": round(likes / total, 4) if total else 0.0,
            "sentiment_counts": sentiment_counts,
            "avg_sentiment": round(score_sum / total, 4) if total else 0.0,
            "engagement_rate": round((likes + replies) / total, 4) if total else 0.0,
        }

    def sentiment_distribution(self, threads: List[Dict[str, Any]]
                               ) -> Dict[str, Any]:
        """Return a sentiment breakdown over comment threads."""
        counts = {"positive": 0, "negative": 0, "neutral": 0}
        for t in threads:
            top = (t.get("snippet", {})
                   .get("topLevelComment", {})
                   .get("snippet", {}))
            text = top.get("textDisplay", top.get("textOriginal", ""))
            counts[analyze_sentiment(text)["label"]] += 1
        total = sum(counts.values()) or 1
        pct = {k: round(100.0 * v / total, 2) for k, v in counts.items()}
        return {"counts": counts, "percentages": pct, "total": total}

    # -- campaign management ---------------------------------------------- #
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

    def record_campaign_metric(self, campaign_id: str, metric: str,
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

    # -- reporting --------------------------------------------------------- #
    def report(self, threads: Optional[List[Dict[str, Any]]] = None,
               channel_id: Optional[str] = None) -> Dict[str, Any]:
        """Produce a consolidated analytics report."""
        threads = threads or []
        report = {
            "generated_at": _now(),
            "channel_id": channel_id,
            "engagement": self.engagement_summary(threads),
            "sentiment": self.sentiment_distribution(threads),
        }
        self._emit("report_generated", channel_id=channel_id,
                   thread_count=len(threads))
        return report