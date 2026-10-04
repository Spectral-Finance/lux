"""
Callback query handling, compact payload codec, and pagination navigation.

Supports Telegram's 64-byte inline button data constraints, stateful codecs,
pattern-based action routing, and pagination keyboard generation with answerCallbackQuery
acknowledgments.
"""

from __future__ import annotations

import inspect
import json
import re
from dataclasses import dataclass, field
from typing import Any, Callable, Coroutine, Dict, List, Optional, Tuple, Union

from lux.telegram.types import (
    CallbackQuery,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    Message,
    PermissionLevel,
    User,
)


class CallbackError(Exception):
    """Base exception for callback processing errors."""
    pass


class CallbackPayloadTooLargeError(CallbackError):
    """Raised when callback_data exceeds Telegram's 64-byte limit."""
    pass


@dataclass
class CallbackDataPayload:
    """Decoded callback query payload."""
    raw_data: str
    action: str
    target: Optional[str] = None
    item_id: Optional[str] = None
    params: Dict[str, Any] = field(default_factory=dict)
    page: Optional[int] = None
    total_pages: Optional[int] = None


@dataclass
class CallbackAnswer:
    """Structure for answering a callback query via Telegram answerCallbackQuery API."""
    callback_query_id: str
    text: Optional[str] = None
    show_alert: bool = False
    url: Optional[str] = None
    cache_time: int = 0

    def to_api_payload(self) -> Dict[str, Any]:
        """Converts to Telegram Bot API answerCallbackQuery request payload."""
        payload: Dict[str, Any] = {"callback_query_id": self.callback_query_id}
        if self.text is not None:
            payload["text"] = self.text
        if self.show_alert:
            payload["show_alert"] = self.show_alert
        if self.url is not None:
            payload["url"] = self.url
        if self.cache_time > 0:
            payload["cache_time"] = self.cache_time
        return payload


@dataclass
class CallbackHandlerDefinition:
    """Registered callback action metadata."""
    pattern: str
    handler: Callable[..., Any]
    permission: PermissionLevel = PermissionLevel.USER
    is_regex: bool = False


class CallbackProcessor:
    """Production processor for inline keyboard callbacks and pagination."""

    MAX_CALLBACK_BYTES = 64

    def __init__(self):
        self._handlers: List[CallbackHandlerDefinition] = []

    @classmethod
    def encode(
        cls,
        action: str,
        target: Optional[str] = None,
        item_id: Optional[Union[str, int]] = None,
        params: Optional[Dict[str, Any]] = None,
    ) -> str:
        """Encodes action parameters into a compact colon-delimited callback string.

        Enforces strict <= 64 byte limit.
        Format: action:target:id[:key=val]
        """
        parts = [action]
        if target is not None:
            parts.append(str(target))
            if item_id is not None:
                parts.append(str(item_id))
        elif item_id is not None:
            parts.append("")
            parts.append(str(item_id))

        if params:
            param_strs = [f"{k}={v}" for k, v in params.items()]
            parts.extend(param_strs)

        result = ":".join(parts)
        byte_len = len(result.encode("utf-8"))
        if byte_len > cls.MAX_CALLBACK_BYTES:
            raise CallbackPayloadTooLargeError(
                f"Callback data exceeds {cls.MAX_CALLBACK_BYTES} bytes ({byte_len} bytes): '{result}'"
            )

        return result

    @classmethod
    def decode(cls, data: Optional[str]) -> CallbackDataPayload:
        """Decodes colon-delimited or JSON callback string into CallbackDataPayload."""
        if not data:
            return CallbackDataPayload(raw_data="", action="default")

        clean_data = str(data).strip()

        # Handle JSON format if present
        if clean_data.startswith("{") and clean_data.endswith("}"):
            try:
                parsed_json = json.loads(clean_data)
                return CallbackDataPayload(
                    raw_data=clean_data,
                    action=parsed_json.get("a") or parsed_json.get("action") or "default",
                    target=parsed_json.get("t") or parsed_json.get("target"),
                    item_id=str(parsed_json.get("i") or parsed_json.get("id")) if "i" in parsed_json or "id" in parsed_json else None,
                    params=parsed_json.get("p") or parsed_json.get("params") or {},
                )
            except Exception:
                pass

        # Colon-delimited format: action:target:id:param1=v1
        parts = clean_data.split(":")
        action = parts[0]
        target = parts[1] if len(parts) > 1 and parts[1] != "" else None
        item_id = parts[2] if len(parts) > 2 and parts[2] != "" else None

        params: Dict[str, Any] = {}
        page_val = None
        total_pages_val = None

        if action == "page" and len(parts) >= 4:
            # Pagination payload: page:resource:cur_page:total_pages[:page_size]
            target = parts[1]
            try:
                page_val = int(parts[2])
                total_pages_val = int(parts[3])
                params["page"] = page_val
                params["total_pages"] = total_pages_val
                params["p"] = str(page_val)
                params["tp"] = str(total_pages_val)
                if len(parts) >= 5:
                    params["page_size"] = int(parts[4])
                    params["ps"] = str(parts[4])
            except ValueError:
                pass
        else:
            # Generic parameters after id
            for p in parts[3:]:
                if "=" in p:
                    k, v = p.split("=", 1)
                    params[k] = v
                else:
                    params[p] = True

        return CallbackDataPayload(
            raw_data=clean_data,
            action=action,
            target=target,
            item_id=item_id,
            params=params,
            page=page_val,
            total_pages=total_pages_val,
        )

    def register(
        self,
        pattern: str,
        handler: Callable[..., Any],
        permission: PermissionLevel = PermissionLevel.USER,
        is_regex: bool = False,
    ) -> None:
        """Registers a handler for a callback action pattern."""
        self._handlers.append(
            CallbackHandlerDefinition(
                pattern=pattern,
                handler=handler,
                permission=permission,
                is_regex=is_regex,
            )
        )

    def on(
        self,
        pattern: str,
        permission: PermissionLevel = PermissionLevel.USER,
        is_regex: bool = False,
    ):
        """Decorator for registering callback handlers."""
        def decorator(func: Callable[..., Any]):
            self.register(pattern, func, permission=permission, is_regex=is_regex)
            return func
        return decorator

    def process(
        self,
        callback_query: CallbackQuery,
        user_permission: PermissionLevel = PermissionLevel.USER,
    ) -> Tuple[Optional[CallbackAnswer], Any]:
        """Synchronously processes a callback query and returns an acknowledgment and handler result."""
        return self._dispatch(callback_query, user_permission, is_async=False)

    async def process_async(
        self,
        callback_query: CallbackQuery,
        user_permission: PermissionLevel = PermissionLevel.USER,
    ) -> Tuple[Optional[CallbackAnswer], Any]:
        """Asynchronously processes a callback query."""
        return await self._dispatch(callback_query, user_permission, is_async=True)

    def _dispatch(
        self,
        callback_query: CallbackQuery,
        user_permission: PermissionLevel,
        is_async: bool,
    ) -> Any:
        data_str = callback_query.data or ""
        payload = self.decode(data_str)

        matched_def = None
        for h in self._handlers:
            if h.is_regex:
                if re.match(h.pattern, data_str):
                    matched_def = h
                    break
            else:
                if h.pattern == payload.action or h.pattern == f"{payload.action}:*" or h.pattern == "*":
                    matched_def = h
                    break

        if not matched_def:
            default_answer = CallbackAnswer(
                callback_query_id=callback_query.id,
                text="Action acknowledged",
            )
            return default_answer, None

        if user_permission.value < matched_def.permission.value:
            answer = CallbackAnswer(
                callback_query_id=callback_query.id,
                text="⚠️ You do not have permission to perform this action.",
                show_alert=True,
            )
            return answer, None

        handler = matched_def.handler
        sig = inspect.signature(handler)
        args: List[Any] = []

        if len(sig.parameters) >= 2:
            args = [callback_query, payload]
        elif len(sig.parameters) == 1:
            args = [callback_query]

        if is_async:
            if inspect.iscoroutinefunction(handler):
                return self._async_call(handler, args, callback_query.id)
            else:
                res = handler(*args)
                return self._format_result(res, callback_query.id)
        else:
            res = handler(*args)
            return self._format_result(res, callback_query.id)

    async def _async_call(self, handler: Callable, args: List[Any], query_id: str) -> Tuple[Optional[CallbackAnswer], Any]:
        res = await handler(*args)
        return self._format_result(res, query_id)

    def _format_result(self, result: Any, query_id: str) -> Tuple[Optional[CallbackAnswer], Any]:
        if isinstance(result, CallbackAnswer):
            return result, result
        if isinstance(result, str):
            answer = CallbackAnswer(callback_query_id=query_id, text=result)
            return answer, result
        if isinstance(result, tuple) and len(result) == 2 and isinstance(result[0], CallbackAnswer):
            return result[0], result[1]

        answer = CallbackAnswer(callback_query_id=query_id)
        return answer, result

    @classmethod
    def create_pagination_keyboard(
        cls,
        resource: str,
        current_page: int,
        total_pages: int,
        page_size: int = 10,
        extra_prefix: Optional[str] = None,
    ) -> InlineKeyboardMarkup:
        """Constructs an inline keyboard row for pagination navigation: [⏮ 1] [◀ Prev] [· p/tp ·] [Next ▶] [⏭ tp]."""
        if total_pages <= 1:
            return InlineKeyboardMarkup(inline_keyboard=[])

        buttons: List[InlineKeyboardButton] = []
        res_key = f"{extra_prefix}_{resource}" if extra_prefix else resource

        # First page button if > 2 pages away
        if current_page > 2:
            first_data = f"page:{res_key}:1:{total_pages}:{page_size}"
            buttons.append(InlineKeyboardButton(text="⏮ 1", callback_data=first_data))

        # Prev button
        if current_page > 1:
            prev_data = f"page:{res_key}:{current_page - 1}:{total_pages}:{page_size}"
            buttons.append(InlineKeyboardButton(text="◀ Prev", callback_data=prev_data))

        # Current page indicator (inert)
        curr_data = f"page:{res_key}:{current_page}:{total_pages}:{page_size}"
        buttons.append(InlineKeyboardButton(text=f"· {current_page}/{total_pages} ·", callback_data=curr_data))

        # Next button
        if current_page < total_pages:
            next_data = f"page:{res_key}:{current_page + 1}:{total_pages}:{page_size}"
            buttons.append(InlineKeyboardButton(text="Next ▶", callback_data=next_data))

        # Last page button if > 2 pages away
        if current_page < total_pages - 1:
            last_data = f"page:{res_key}:{total_pages}:{total_pages}:{page_size}"
            buttons.append(InlineKeyboardButton(text=f"⏭ {total_pages}", callback_data=last_data))

        return InlineKeyboardMarkup(inline_keyboard=[buttons])
