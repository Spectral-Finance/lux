"""
discord_prisms.prisms — the four prisms required by lux issue #57.

Each prism subclasses :class:`discord_prisms.core.Prism` and implements the
features listed in the issue's acceptance criteria:

  * MessageManagementPrism  ($600) — create/edit/delete/bulk-delete + history
  * ChannelManagementPrism  ($500) — CRUD, permissions, config, archive
  * ModerationPrism         ($500) — content filter, timeout, ban/unban, warnings
  * EventHandlingPrism      ($400) — schedule, reminders, notifications, persist

Every operation:
  * goes through the shared rate-limited / retrying HTTP core,
  * emits a structured event via the shared EventEmitter,
  * persists state via the shared persistence hook where relevant.
"""

from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

from .core import Prism

__all__ = [
    "MessageManagementPrism",
    "ChannelManagementPrism",
    "ModerationPrism",
    "EventHandlingPrism",
]


class MessageManagementPrism(Prism):
    """Message creation, editing, deletion, bulk operations, history."""

    name = "MessageManagement"

    def create_message(self, channel_id: str, content: str,
                       tts: bool = False,
                       embeds: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        body: Dict[str, Any] = {"content": content, "tts": tts}
        if embeds:
            body["embeds"] = embeds
        msg = self.http.request("POST", f"/channels/{channel_id}/messages",
                                json_body=body)
        self._emit("message_created", channel_id=channel_id,
                   message_id=msg.get("id"), content=content)
        return msg

    def edit_message(self, channel_id: str, message_id: str,
                     content: str,
                     embeds: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        body: Dict[str, Any] = {"content": content}
        if embeds is not None:
            body["embeds"] = embeds
        msg = self.http.request(
            "PATCH", f"/channels/{channel_id}/messages/{message_id}",
            json_body=body)
        self._emit("message_edited", channel_id=channel_id,
                   message_id=message_id)
        return msg

    def delete_message(self, channel_id: str, message_id: str,
                       reason: Optional[str] = None) -> None:
        params = {"reason": reason} if reason else None
        self.http.request(
            "DELETE", f"/channels/{channel_id}/messages/{message_id}",
            params=params)
        self._emit("message_deleted", channel_id=channel_id,
                   message_id=message_id, reason=reason)

    def bulk_delete(self, channel_id: str, message_ids: List[str],
                    reason: Optional[str] = None) -> None:
        """Delete 2-100 messages (Discord requirement)."""
        if not (2 <= len(message_ids) <= 100):
            raise ValueError("bulk_delete requires between 2 and 100 message IDs")
        params = {"reason": reason} if reason else None
        self.http.request(
            "POST", f"/channels/{channel_id}/messages/bulk-delete",
            json_body={"messages": message_ids}, params=params)
        self._emit("messages_bulk_deleted", channel_id=channel_id,
                   count=len(message_ids))

    def get_history(self, channel_id: str, limit: int = 50,
                    before: Optional[str] = None,
                    after: Optional[str] = None) -> List[Dict[str, Any]]:
        params: Dict[str, Any] = {"limit": max(1, min(100, limit))}
        if before:
            params["before"] = before
        if after:
            params["after"] = after
        msgs = self.http.request(
            "GET", f"/channels/{channel_id}/messages", params=params)
        self._emit("history_fetched", channel_id=channel_id,
                   count=len(msgs) if isinstance(msgs, list) else 0)
        return msgs if isinstance(msgs, list) else []


class ChannelManagementPrism(Prism):
    """Channel CRUD, permission setup, configuration, archive/unarchive."""

    name = "ChannelManagement"

    def create_channel(self, guild_id: str, name: str,
                       channel_type: int = 0,
                       topic: Optional[str] = None,
                       permission_overwrites: Optional[List[Dict[str, Any]]] = None,
                       parent_id: Optional[str] = None) -> Dict[str, Any]:
        body: Dict[str, Any] = {"name": name, "type": channel_type}
        if topic is not None:
            body["topic"] = topic
        if permission_overwrites is not None:
            body["permission_overwrites"] = permission_overwrites
        if parent_id is not None:
            body["parent_id"] = parent_id
        ch = self.http.request("POST", f"/guilds/{guild_id}/channels",
                               json_body=body)
        self._emit("channel_created", guild_id=guild_id,
                   channel_id=ch.get("id"), name=name)
        return ch

    def update_channel(self, channel_id: str,
                       **fields: Any) -> Dict[str, Any]:
        ch = self.http.request("PATCH", f"/channels/{channel_id}",
                               json_body=fields)
        self._emit("channel_updated", channel_id=channel_id, fields=list(fields))
        return ch

    def delete_channel(self, channel_id: str,
                       reason: Optional[str] = None) -> Dict[str, Any]:
        params = {"reason": reason} if reason else None
        ch = self.http.request("DELETE", f"/channels/{channel_id}", params=params)
        self._emit("channel_deleted", channel_id=channel_id, reason=reason)
        return ch

    def set_permissions(self, channel_id: str, overwrite_id: str,
                        allow: int = 0, deny: int = 0,
                        permission_type: int = 0) -> Dict[str, Any]:
        body = {"allow": str(allow), "deny": str(deny), "type": permission_type}
        ow = self.http.request(
            "PUT", f"/channels/{channel_id}/permissions/{overwrite_id}",
            json_body=body)
        self._emit("permissions_set", channel_id=channel_id,
                   overwrite_id=overwrite_id)
        return ow

    def archive_channel(self, channel_id: str,
                        reason: Optional[str] = None) -> Dict[str, Any]:
        ch = self.update_channel(channel_id, archived=True)
        self._emit("channel_archived", channel_id=channel_id, reason=reason)
        return ch

    def unarchive_channel(self, channel_id: str,
                          reason: Optional[str] = None) -> Dict[str, Any]:
        ch = self.update_channel(channel_id, archived=False)
        self._emit("channel_unarchived", channel_id=channel_id, reason=reason)
        return ch


class ModerationPrism(Prism):
    """Content filtering, timeouts, ban/unban, warning system."""

    name = "Moderation"

    def __init__(self, *args, banned_words: Optional[List[str]] = None, **kwargs):
        super().__init__(*args, **kwargs)
        self.banned_words = [w.lower() for w in (banned_words or [])]

    def filter_content(self, content: str) -> Dict[str, Any]:
        """Return a moderation verdict for `content` (no API call)."""
        lowered = content.lower()
        hits = [w for w in self.banned_words if w and w in lowered]
        verdict = {
            "clean": not hits,
            "matched": hits,
            "action": "flag" if hits else "allow",
        }
        self._emit("content_filtered", clean=verdict["clean"], hits=hits)
        return verdict

    def timeout_member(self, guild_id: str, member_id: str,
                       duration_seconds: int,
                       reason: Optional[str] = None) -> None:
        """Time out a member (Discord requires ISO8601 duration until)."""
        if duration_seconds <= 0:
            raise ValueError("duration_seconds must be positive")
        until = _iso8601_duration(duration_seconds)
        params = {"reason": reason} if reason else None
        self.http.request(
            "PATCH", f"/guilds/{guild_id}/members/{member_id}",
            json_body={"communication_disabled_until": until}, params=params)
        self._emit("member_timed_out", guild_id=guild_id, member_id=member_id,
                   duration_seconds=duration_seconds)

    def ban_member(self, guild_id: str, user_id: str,
                   delete_message_seconds: int = 0,
                   reason: Optional[str] = None) -> None:
        params: Dict[str, Any] = {}
        if reason:
            params["reason"] = reason
        if delete_message_seconds:
            params["delete_message_seconds"] = str(delete_message_seconds)
        self.http.request("PUT", f"/guilds/{guild_id}/bans/{user_id}",
                          params=params or None)
        self._emit("member_banned", guild_id=guild_id, user_id=user_id,
                   reason=reason)

    def unban_member(self, guild_id: str, user_id: str,
                     reason: Optional[str] = None) -> None:
        params = {"reason": reason} if reason else None
        self.http.request("DELETE", f"/guilds/{guild_id}/bans/{user_id}",
                          params=params)
        self._emit("member_unbanned", guild_id=guild_id, user_id=user_id)

    def add_warning(self, guild_id: str, user_id: str, reason: str,
                    moderator_id: Optional[str] = None) -> Dict[str, Any]:
        key = f"warnings:{guild_id}:{user_id}"
        warnings = self.persistence.get(key, [])
        warning = {
            "reason": reason,
            "moderator_id": moderator_id,
            "created_at": int(time.time()),
        }
        warnings.append(warning)
        self.persistence.set(key, warnings)
        self._emit("warning_added", guild_id=guild_id, user_id=user_id,
                   total=len(warnings))
        return warning

    def get_warnings(self, guild_id: str, user_id: str) -> List[Dict[str, Any]]:
        return self.persistence.get(f"warnings:{guild_id}:{user_id}", [])

    def clear_warnings(self, guild_id: str, user_id: str) -> None:
        self.persistence.delete(f"warnings:{guild_id}:{user_id}")
        self._emit("warnings_cleared", guild_id=guild_id, user_id=user_id)


class EventHandlingPrism(Prism):
    """Event scheduling, reminders, notifications, persistence."""

    name = "EventHandling"

    def schedule_event(self, guild_id: str, name: str,
                       scheduled_start_time: str,
                       entity_type: int = 3,
                       channel_id: Optional[str] = None,
                       description: Optional[str] = None) -> Dict[str, Any]:
        body: Dict[str, Any] = {
            "name": name,
            "scheduled_start_time": scheduled_start_time,
            "entity_type": entity_type,
            "privacy_level": 2,  # GUILD_ONLY
        }
        if channel_id:
            body["channel_id"] = channel_id
        if description:
            body["description"] = description
        ev = self.http.request("POST", f"/guilds/{guild_id}/scheduled-events",
                               json_body=body)
        self._persist_event(ev)
        self._emit("event_scheduled", guild_id=guild_id,
                   event_id=ev.get("id"), name=name)
        return ev

    def _persist_event(self, event: Dict[str, Any]) -> None:
        eid = event.get("id")
        if eid:
            self.persistence.set(f"event:{eid}", event)

    def add_reminder(self, event_id: str, remind_at_epoch: int,
                     channel_id: Optional[str] = None,
                     message: Optional[str] = None) -> Dict[str, Any]:
        """Register a reminder for an event (evaluated by ``due_reminders``)."""
        reminder = {
            "event_id": event_id,
            "remind_at": remind_at_epoch,
            "channel_id": channel_id,
            "message": message or "Event starting soon",
            "sent": False,
        }
        key = f"reminders:{event_id}"
        reminders = self.persistence.get(key, [])
        reminders.append(reminder)
        self.persistence.set(key, reminders)
        self._emit("reminder_added", event_id=event_id,
                   remind_at=remind_at_epoch)
        return reminder

    def due_reminders(self, now_epoch: Optional[int] = None) -> List[Dict[str, Any]]:
        """Return reminders that are due and not yet sent (does not send)."""
        now = now_epoch if now_epoch is not None else int(time.time())
        due: List[Dict[str, Any]] = []
        for key in list(self.persistence.all().keys()):
            if not key.startswith("reminders:"):
                continue
            for r in self.persistence.get(key, []):
                if not r.get("sent") and r.get("remind_at", 0) <= now:
                    due.append(r)
        return due

    def notify(self, channel_id: str, message: str) -> Dict[str, Any]:
        """Send an event notification message to a channel."""
        msg = self.http.request(
            "POST", f"/channels/{channel_id}/messages",
            json_body={"content": message})
        self._emit("notification_sent", channel_id=channel_id,
                   message_id=msg.get("id"))
        return msg

    def delete_event(self, guild_id: str, event_id: str) -> None:
        self.http.request(
            "DELETE", f"/guilds/{guild_id}/scheduled-events/{event_id}")
        self.persistence.delete(f"event:{event_id}")
        self._emit("event_deleted", guild_id=guild_id, event_id=event_id)


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def _iso8601_duration(seconds: int) -> str:
    """Convert a duration in seconds to an ISO8601 duration (e.g. PT1H30M)."""
    days, rem = divmod(int(seconds), 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)
    out = "P"
    if days:
        out += f"{days}D"
    out += "T"
    if hours:
        out += f"{hours}H"
    if minutes:
        out += f"{minutes}M"
    if secs or out == "PT":
        out += f"{secs}S"
    return out