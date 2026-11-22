"""
telegram_prisms.prisms — the Telegram prisms required by lux issue #62.

Each prism subclasses :class:`telegram_prisms.core.Prism` and implements the
features listed in the issue's acceptance criteria:

  * BotPrism        — authentication / getMe, bot profile & webhook info
  * MessagePrism    — send / edit / delete text messages, forward, copy
  * MediaPrism      — sendPhoto / sendDocument / sendVoice / sendVideo / audio
  * KeyboardPrism   — inline keyboards, reply keyboards, callback answers
  * WebhookPrism    — setWebhook / deleteWebhook / getWebhookInfo / getUpdates
  * UpdatePrism     — high-level update dispatch (messages, callbacks, etc.)

Every operation:
  * goes through the shared rate-limited / retrying HTTP core,
  * emits a structured event via the shared EventEmitter,
  * persists state via the shared persistence hook where relevant.
"""

from __future__ import annotations

import time
from typing import Any, Callable, Dict, List, Optional

from .core import Prism

__all__ = [
    "BotPrism",
    "MessagePrism",
    "MediaPrism",
    "KeyboardPrism",
    "WebhookPrism",
    "UpdatePrism",
]


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def _drop_none(d: Dict[str, Any]) -> Dict[str, Any]:
    """Return a copy of ``d`` without ``None`` values (Telegram rejects nulls)."""
    return {k: v for k, v in d.items() if v is not None}


def _inline_keyboard(rows: List[List[Dict[str, Any]]]) -> Dict[str, Any]:
    return {"inline_keyboard": rows}


def _reply_keyboard(rows: List[List[Dict[str, Any]]], **opts: Any) -> Dict[str, Any]:
    kb: Dict[str, Any] = {"keyboard": rows}
    kb.update(opts)
    return kb


# --------------------------------------------------------------------------- #
# BotPrism — authentication / bot management
# --------------------------------------------------------------------------- #
class BotPrism(Prism):
    """Bot authentication and profile management (getMe, profile, webhook info)."""

    name = "Bot"

    def get_me(self) -> Dict[str, Any]:
        """Return the bot's own user object (validates the token)."""
        me = self.http.request("getMe")
        self._emit("authenticated", bot_id=me.get("id"),
                   username=me.get("username"))
        return me

    def whoami(self) -> Dict[str, Any]:
        """Alias for :meth:`get_me`."""
        return self.get_me()

    def get_my_name(self) -> str:
        return self.get_me().get("first_name", "")

    def get_my_commands(self) -> List[Dict[str, Any]]:
        return self.http.request("getMyCommands") or []

    def set_my_commands(self, commands: List[Dict[str, str]]) -> bool:
        result = self.http.request("setMyCommands", {"commands": commands})
        self._emit("commands_set", count=len(commands))
        return bool(result)

    def delete_my_commands(self) -> bool:
        return bool(self.http.request("deleteMyCommands"))

    def log_out(self) -> bool:
        """Revoke the current token server-side (bot will stop working)."""
        result = self.http.request("logOut")
        self._emit("logged_out")
        return bool(result)

    def close(self) -> bool:
        return bool(self.http.request("close"))


# --------------------------------------------------------------------------- #
# MessagePrism — text message send / edit / delete / forward / copy
# --------------------------------------------------------------------------- #
class MessagePrism(Prism):
    """Text message handling: send, edit, delete, forward, copy."""

    name = "Message"

    def send_message(self, chat_id: Any, text: str, *,
                     parse_mode: Optional[str] = None,
                     disable_web_page_preview: bool = False,
                     disable_notification: bool = False,
                     reply_to_message_id: Optional[int] = None,
                     reply_markup: Optional[Dict[str, Any]] = None,
                     entities: Optional[List[Dict[str, Any]]] = None,
                     message_thread_id: Optional[int] = None) -> Dict[str, Any]:
        body = _drop_none({
            "chat_id": chat_id,
            "text": text,
            "parse_mode": parse_mode,
            "disable_web_page_preview": disable_web_page_preview or None,
            "disable_notification": disable_notification or None,
            "reply_to_message_id": reply_to_message_id,
            "reply_markup": reply_markup,
            "entities": entities,
            "message_thread_id": message_thread_id,
        })
        msg = self.http.request("sendMessage", body)
        self._emit("message_sent", chat_id=chat_id,
                   message_id=(msg or {}).get("message_id"), text=text)
        return msg

    def reply(self, chat_id: Any, message_id: int, text: str, **kwargs: Any) -> Dict[str, Any]:
        """Reply to a specific message."""
        kwargs["reply_to_message_id"] = message_id
        return self.send_message(chat_id, text, **kwargs)

    def edit_message_text(self, chat_id: Any, message_id: int, text: str, *,
                          parse_mode: Optional[str] = None,
                          disable_web_page_preview: bool = False,
                          reply_markup: Optional[Dict[str, Any]] = None,
                          inline_message_id: Optional[str] = None) -> Dict[str, Any]:
        body = _drop_none({
            "chat_id": None if inline_message_id else chat_id,
            "message_id": None if inline_message_id else message_id,
            "inline_message_id": inline_message_id,
            "text": text,
            "parse_mode": parse_mode,
            "disable_web_page_preview": disable_web_page_preview or None,
            "reply_markup": reply_markup,
        })
        msg = self.http.request("editMessageText", body)
        self._emit("message_edited", chat_id=chat_id, message_id=message_id)
        return msg

    def edit_message_reply_markup(self, chat_id: Any, message_id: int, *,
                                  reply_markup: Optional[Dict[str, Any]] = None,
                                  inline_message_id: Optional[str] = None) -> Dict[str, Any]:
        body = _drop_none({
            "chat_id": None if inline_message_id else chat_id,
            "message_id": None if inline_message_id else message_id,
            "inline_message_id": inline_message_id,
            "reply_markup": reply_markup,
        })
        msg = self.http.request("editMessageReplyMarkup", body)
        self._emit("message_markup_edited", chat_id=chat_id, message_id=message_id)
        return msg

    def delete_message(self, chat_id: Any, message_id: int) -> bool:
        result = self.http.request("deleteMessage",
                                   {"chat_id": chat_id, "message_id": message_id})
        self._emit("message_deleted", chat_id=chat_id, message_id=message_id)
        return bool(result)

    def forward_message(self, chat_id: Any, from_chat_id: Any,
                        message_id: int, *,
                        disable_notification: bool = False) -> Dict[str, Any]:
        body = _drop_none({
            "chat_id": chat_id,
            "from_chat_id": from_chat_id,
            "message_id": message_id,
            "disable_notification": disable_notification or None,
        })
        msg = self.http.request("forwardMessage", body)
        self._emit("message_forwarded", chat_id=chat_id,
                   from_chat_id=from_chat_id, message_id=message_id)
        return msg

    def copy_message(self, chat_id: Any, from_chat_id: Any,
                     message_id: int, *,
                     disable_notification: bool = False) -> Dict[str, Any]:
        body = _drop_none({
            "chat_id": chat_id,
            "from_chat_id": from_chat_id,
            "message_id": message_id,
            "disable_notification": disable_notification or None,
        })
        msg = self.http.request("copyMessage", body)
        self._emit("message_copied", chat_id=chat_id,
                   from_chat_id=from_chat_id, message_id=message_id)
        return msg


# --------------------------------------------------------------------------- #
# MediaPrism — photos / documents / voice / video / audio
# --------------------------------------------------------------------------- #
class MediaPrism(Prism):
    """Media file handling: photos, documents, voice, video, audio."""

    name = "Media"

    def send_photo(self, chat_id: Any, photo: Any, *,
                   caption: Optional[str] = None,
                   parse_mode: Optional[str] = None,
                   disable_notification: bool = False,
                   reply_markup: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Send a photo. ``photo`` may be a file_id/str URL or raw bytes."""
        return self._send_media("sendPhoto", chat_id, "photo", photo,
                                caption=caption, parse_mode=parse_mode,
                                disable_notification=disable_notification,
                                reply_markup=reply_markup)

    def send_document(self, chat_id: Any, document: Any, *,
                      caption: Optional[str] = None,
                      parse_mode: Optional[str] = None,
                      disable_notification: bool = False,
                      reply_markup: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        return self._send_media("sendDocument", chat_id, "document", document,
                                caption=caption, parse_mode=parse_mode,
                                disable_notification=disable_notification,
                                reply_markup=reply_markup)

    def send_voice(self, chat_id: Any, voice: Any, *,
                   caption: Optional[str] = None,
                   parse_mode: Optional[str] = None,
                   duration: Optional[int] = None,
                   disable_notification: bool = False,
                   reply_markup: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        return self._send_media("sendVoice", chat_id, "voice", voice,
                                caption=caption, parse_mode=parse_mode,
                                duration=duration,
                                disable_notification=disable_notification,
                                reply_markup=reply_markup)

    def send_audio(self, chat_id: Any, audio: Any, *,
                   caption: Optional[str] = None,
                   duration: Optional[int] = None,
                   disable_notification: bool = False,
                   reply_markup: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        return self._send_media("sendAudio", chat_id, "audio", audio,
                                caption=caption, duration=duration,
                                disable_notification=disable_notification,
                                reply_markup=reply_markup)

    def send_video(self, chat_id: Any, video: Any, *,
                   caption: Optional[str] = None,
                   duration: Optional[int] = None,
                   disable_notification: bool = False,
                   reply_markup: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        return self._send_media("sendVideo", chat_id, "video", video,
                                caption=caption, duration=duration,
                                disable_notification=disable_notification,
                                reply_markup=reply_markup)

    def _send_media(self, method: str, chat_id: Any, field: str, media: Any, *,
                    caption: Optional[str] = None,
                    parse_mode: Optional[str] = None,
                    duration: Optional[int] = None,
                    disable_notification: bool = False,
                    reply_markup: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Dispatch a media send.

        If ``media`` is raw ``bytes`` we upload it as multipart; otherwise it is
        treated as a file_id / URL string and sent as JSON.
        """
        fields = _drop_none({
            "chat_id": chat_id,
            "caption": caption,
            "parse_mode": parse_mode,
            "duration": duration,
            "disable_notification": disable_notification or None,
            "reply_markup": _json_str(reply_markup),
        })
        if isinstance(media, (bytes, bytearray)):
            msg = self.http.request(method, fields, files={field: bytes(media)})
        else:
            fields[field] = media
            msg = self.http.request(method, fields)
        self._emit("media_sent", chat_id=chat_id, kind=field,
                   message_id=(msg or {}).get("message_id"))
        return msg


# --------------------------------------------------------------------------- #
# KeyboardPrism — inline + reply keyboards, callback answers
# --------------------------------------------------------------------------- #
class KeyboardPrism(Prism):
    """Inline keyboard + custom (reply) keyboard construction and callbacks."""

    name = "Keyboard"

    # -- builders (no API call) ------------------------------------------- #
    @staticmethod
    def inline_button(text: str, **kwargs: Any) -> Dict[str, Any]:
        """Build a single inline keyboard button.

        Exactly one of ``callback_data``, ``url``, ``switch_inline_query`` etc.
        should be supplied.
        """
        return _drop_none({"text": text, **kwargs})

    @classmethod
    def inline_keyboard(cls, rows: List[List[Dict[str, Any]]]) -> Dict[str, Any]:
        return _inline_keyboard(rows)

    @classmethod
    def reply_keyboard(cls, rows: List[List[Dict[str, Any]]], *,
                       resize_keyboard: bool = True,
                       one_time_keyboard: bool = False,
                       selective: bool = False) -> Dict[str, Any]:
        return _reply_keyboard(rows, resize_keyboard=resize_keyboard,
                               one_time_keyboard=one_time_keyboard,
                               selective=selective)

    @staticmethod
    def remove_reply_keyboard(selective: bool = False) -> Dict[str, Any]:
        return {"remove_keyboard": True, "selective": selective}

    # -- API calls --------------------------------------------------------- #
    def answer_callback_query(self, callback_query_id: str, *,
                              text: Optional[str] = None,
                              show_alert: bool = False,
                              url: Optional[str] = None,
                              cache_time: int = 0) -> bool:
        body = _drop_none({
            "callback_query_id": callback_query_id,
            "text": text,
            "show_alert": show_alert or None,
            "url": url,
            "cache_time": cache_time or None,
        })
        result = self.http.request("answerCallbackQuery", body)
        self._emit("callback_answered", callback_query_id=callback_query_id)
        return bool(result)

    def set_chat_menu_button(self, chat_id: Optional[Any] = None,
                             menu_button: Optional[Dict[str, Any]] = None) -> bool:
        body = _drop_none({"chat_id": chat_id, "menu_button": menu_button})
        return bool(self.http.request("setChatMenuButton", body))


# --------------------------------------------------------------------------- #
# WebhookPrism — webhook + updates handling
# --------------------------------------------------------------------------- #
class WebhookPrism(Prism):
    """Webhook registration and long-poll update retrieval."""

    name = "Webhook"

    def set_webhook(self, url: str, *,
                    secret_token: Optional[str] = None,
                    certificate: Optional[bytes] = None,
                    allowed_updates: Optional[List[str]] = None,
                    drop_pending_updates: bool = False,
                    max_connections: Optional[int] = None) -> bool:
        fields = _drop_none({
            "url": url,
            "secret_token": secret_token,
            "allowed_updates": _json_str(allowed_updates),
            "drop_pending_updates": drop_pending_updates or None,
            "max_connections": max_connections,
        })
        if certificate is not None:
            result = self.http.request("setWebhook", fields,
                                       files={"certificate": certificate})
        else:
            result = self.http.request("setWebhook", fields)
        self._emit("webhook_set", url=url)
        return bool(result)

    def delete_webhook(self, *, drop_pending_updates: bool = False) -> bool:
        body = _drop_none({"drop_pending_updates": drop_pending_updates or None})
        result = self.http.request("deleteWebhook", body)
        self._emit("webhook_deleted")
        return bool(result)

    def get_webhook_info(self) -> Dict[str, Any]:
        info = self.http.request("getWebhookInfo")
        self._emit("webhook_info", url=(info or {}).get("url"))
        return info

    def get_updates(self, *,
                    offset: Optional[int] = None,
                    limit: Optional[int] = None,
                    timeout: int = 0,
                    allowed_updates: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        body = _drop_none({
            "offset": offset,
            "limit": limit,
            "timeout": timeout or None,
            "allowed_updates": _json_str(allowed_updates),
        })
        updates = self.http.request("getUpdates", body) or []
        self._emit("updates_fetched", count=len(updates))
        return updates


# --------------------------------------------------------------------------- #
# UpdatePrism — high-level update dispatch
# --------------------------------------------------------------------------- #
class UpdatePrism(Prism):
    """High-level update handling: dispatch updates to registered handlers.

    Handlers are registered per update ``type`` (e.g. ``"message"``,
    ``"callback_query"``). :meth:`process_update` routes a single raw update to
    the matching handler(s) and :meth:`poll` drains updates from Telegram.
    """

    name = "Update"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self._handlers: Dict[str, List[Callable[[Dict[str, Any]], None]]] = {}
        self._offset: Optional[int] = None

    def register(self, update_type: str,
                 handler: Callable[[Dict[str, Any]], None]) -> Callable:
        """Register a handler for an update type (e.g. ``"message"``)."""
        self._handlers.setdefault(update_type, []).append(handler)
        return handler

    def on_message(self, handler: Callable[[Dict[str, Any]], None]) -> Callable:
        return self.register("message", handler)

    def on_callback_query(self, handler: Callable[[Dict[str, Any]], None]) -> Callable:
        return self.register("callback_query", handler)

    def on_edited_message(self, handler: Callable[[Dict[str, Any]], None]) -> Callable:
        return self.register("edited_message", handler)

    @staticmethod
    def classify(update: Dict[str, Any]) -> Optional[str]:
        """Return the primary update type key for a raw update dict."""
        for key in ("message", "edited_message", "channel_post",
                    "callback_query", "inline_query", "my_chat_member",
                    "chat_member", "chat_join_request"):
            if key in update:
                return key
        return None

    def process_update(self, update: Dict[str, Any]) -> List[Any]:
        """Route a single update to matching handlers; return handler results."""
        utype = self.classify(update)
        self._emit("update_received", update_type=utype,
                   update_id=update.get("update_id"))
        if utype is None:
            return []
        results = []
        for handler in list(self._handlers.get(utype, [])):
            try:
                results.append(handler(update))
            except Exception as exc:  # noqa: BLE001 - isolate handler failures
                self._emit("handler_error", update_type=utype, error=str(exc))
        return results

    def process_updates(self, updates: List[Dict[str, Any]]) -> int:
        """Process a batch of updates; return the count handled."""
        for upd in updates:
            self.process_update(upd)
            uid = upd.get("update_id")
            if isinstance(uid, int):
                self._offset = uid + 1
        return len(updates)

    def poll(self, *, timeout: int = 0,
             limit: Optional[int] = None) -> int:
        """Fetch updates via long-poll and dispatch them; return count handled."""
        updates = self.http.request("getUpdates", _drop_none({
            "offset": self._offset,
            "timeout": timeout or None,
            "limit": limit,
        })) or []
        return self.process_updates(updates)


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def _json_str(value: Any) -> Optional[str]:
    """Serialise ``value`` to a JSON string for Telegram fields, or None."""
    if value is None:
        return None
    import json
    return json.dumps(value)