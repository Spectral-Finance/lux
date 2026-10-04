"""
Thread management system for Telegram message threads and conversation context.

Provides ring-buffered conversation history, LRU session memory with TTL eviction,
context window trimming for LLM token limits, forum topic ID tracking, and thread
state machine transitions.
"""

from __future__ import annotations

import collections
import math
import time
from typing import Any, Callable, Deque, Dict, List, Optional, Set, Tuple

from lux.telegram.types import (
    Message,
    ThreadContext,
    ThreadState,
    User,
)


class ThreadTransitionError(Exception):
    """Raised when an invalid thread state transition is requested."""
    pass


class ConversationMessage:
    """Wrapper for history messages stored in the ring buffer."""

    def __init__(
        self,
        message_id: int,
        sender_id: int,
        sender_name: str,
        text: str,
        timestamp: float = 0.0,
        is_bot: bool = False,
        reply_to_id: Optional[int] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ):
        self.message_id = message_id
        self.sender_id = sender_id
        self.sender_name = sender_name
        self.text = text
        self.timestamp = timestamp or time.time()
        self.is_bot = is_bot
        self.reply_to_id = reply_to_id
        self.metadata = metadata or {}

    @property
    def estimated_tokens(self) -> int:
        """Estimates token count (~4 characters per token)."""
        return max(1, math.ceil(len(self.text) / 4.0))

    def to_dict(self) -> Dict[str, Any]:
        return {
            "message_id": self.message_id,
            "sender_id": self.sender_id,
            "sender_name": self.sender_name,
            "text": self.text,
            "timestamp": self.timestamp,
            "is_bot": self.is_bot,
            "reply_to_id": self.reply_to_id,
            "metadata": self.metadata,
        }

    @classmethod
    def from_message(cls, message: Message, is_bot: bool = False) -> ConversationMessage:
        user_id = message.from_user.id if message.from_user else 0
        user_name = message.from_user.full_name if message.from_user else "Unknown"
        text = message.effective_text
        reply_id = message.reply_to_message.message_id if message.reply_to_message else None
        return cls(
            message_id=message.message_id,
            sender_id=user_id,
            sender_name=user_name,
            text=text,
            timestamp=float(message.date) if message.date else time.time(),
            is_bot=is_bot,
            reply_to_id=reply_id,
        )


class ConversationSession:
    """Active session container holding history buffer and thread state."""

    VALID_TRANSITIONS: Dict[ThreadState, Set[ThreadState]] = {
        ThreadState.ACTIVE: {ThreadState.IDLE, ThreadState.PAUSED, ThreadState.CLOSED},
        ThreadState.IDLE: {ThreadState.ACTIVE, ThreadState.PAUSED, ThreadState.CLOSED, ThreadState.ARCHIVED},
        ThreadState.PAUSED: {ThreadState.ACTIVE, ThreadState.CLOSED, ThreadState.ARCHIVED},
        ThreadState.CLOSED: {ThreadState.ACTIVE, ThreadState.ARCHIVED},
        ThreadState.ARCHIVED: {ThreadState.ACTIVE},
    }

    def __init__(
        self,
        chat_id: int,
        topic_id: Optional[int] = None,
        max_history: int = 50,
        ttl_seconds: float = 3600.0,
    ):
        self.chat_id = chat_id
        self.topic_id = topic_id
        self.thread_id = self.build_thread_id(chat_id, topic_id)
        self.max_history = max_history
        self.ttl_seconds = ttl_seconds
        self.created_at = time.time()
        self.last_activity_at = time.time()
        self.state = ThreadState.ACTIVE
        self.history: Deque[ConversationMessage] = collections.deque(maxlen=max_history)
        self.participants: Set[int] = set()
        self.metadata: Dict[str, Any] = {}

    @staticmethod
    def build_thread_id(chat_id: int, topic_id: Optional[int] = None) -> str:
        """Constructs a unique thread key combining chat ID and topic ID."""
        if topic_id is not None:
            return f"{chat_id}:{topic_id}"
        return f"{chat_id}:main"

    def is_expired(self, current_time: Optional[float] = None) -> bool:
        """Checks if session has expired past TTL."""
        now = current_time or time.time()
        return (now - self.last_activity_at) > self.ttl_seconds

    def touch(self) -> None:
        """Updates last activity timestamp and reactivates idle threads."""
        self.last_activity_at = time.time()
        if self.state == ThreadState.IDLE:
            self.state = ThreadState.ACTIVE

    def transition_to(self, new_state: ThreadState) -> None:
        """Transitions thread to a new state with validation."""
        if new_state == self.state:
            return
        allowed = self.VALID_TRANSITIONS.get(self.state, set())
        if new_state not in allowed:
            raise ThreadTransitionError(
                f"Cannot transition thread '{self.thread_id}' from {self.state.value} to {new_state.value}"
            )
        self.state = new_state
        self.touch()

    def add_message(self, msg: ConversationMessage) -> None:
        """Appends a message to the ring buffer."""
        self.history.append(msg)
        self.participants.add(msg.sender_id)
        self.touch()

    def get_messages(self, limit: Optional[int] = None) -> List[ConversationMessage]:
        """Returns recent messages in chronological order."""
        msgs = list(self.history)
        if limit and limit < len(msgs):
            return msgs[-limit:]
        return msgs

    def trim_context_window(
        self,
        max_tokens: int = 2000,
        keep_system: bool = True,
        system_prompt: Optional[str] = None,
    ) -> List[Dict[str, str]]:
        """Trims conversation history to fit within a token budget for LLM contexts.

        Returns a list of role/content dicts formatted for chat completion APIs.
        """
        formatted_messages: List[Dict[str, str]] = []
        budget = max_tokens

        # Reserve tokens for system prompt if supplied
        if system_prompt:
            sys_tokens = max(1, math.ceil(len(system_prompt) / 4.0))
            budget -= sys_tokens

        # Chronological reverse collection (most recent first)
        selected_messages: List[ConversationMessage] = []
        used_tokens = 0

        for msg in reversed(self.history):
            tok = msg.estimated_tokens
            if used_tokens + tok > budget and selected_messages:
                break
            selected_messages.append(msg)
            used_tokens += tok

        # Restore chronological order
        selected_messages.reverse()

        if system_prompt:
            formatted_messages.append({"role": "system", "content": system_prompt})

        for m in selected_messages:
            role = "assistant" if m.is_bot else "user"
            formatted_messages.append({
                "role": role,
                "content": f"{m.sender_name}: {m.text}" if role == "user" else m.text,
            })

        return formatted_messages

    def to_context(self) -> ThreadContext:
        """Converts session to a ThreadContext model."""
        return ThreadContext(
            thread_id=self.thread_id,
            chat_id=self.chat_id,
            topic_id=self.topic_id,
            state=self.state,
            created_at=self.created_at,
            last_activity_at=self.last_activity_at,
            message_count=len(self.history),
            user_ids=self.participants,
            metadata=self.metadata,
        )


class ThreadManager:
    """Thread and session lifecycle manager with LRU eviction and memory bounds."""

    def __init__(
        self,
        capacity: int = 1000,
        default_max_history: int = 50,
        default_ttl: float = 3600.0,
    ):
        self.capacity = capacity
        self.default_max_history = default_max_history
        self.default_ttl = default_ttl
        self._sessions: collections.OrderedDict[str, ConversationSession] = collections.OrderedDict()
        self._listeners: List[Callable[[str, ThreadState], None]] = []

    def get_or_create_session(
        self,
        chat_id: int,
        topic_id: Optional[int] = None,
        max_history: Optional[int] = None,
        ttl_seconds: Optional[float] = None,
    ) -> ConversationSession:
        """Retrieves an existing session or creates a new one, evicting LRU if full."""
        thread_id = ConversationSession.build_thread_id(chat_id, topic_id)

        if thread_id in self._sessions:
            session = self._sessions[thread_id]
            # Check expiration
            if session.is_expired():
                session.history.clear()
                session.created_at = time.time()
                session.state = ThreadState.ACTIVE
            session.touch()
            self._sessions.move_to_end(thread_id)
            return session

        # Capacity management: Evict LRU expired or oldest session
        if len(self._sessions) >= self.capacity:
            self._evict_lru()

        session = ConversationSession(
            chat_id=chat_id,
            topic_id=topic_id,
            max_history=max_history or self.default_max_history,
            ttl_seconds=ttl_seconds or self.default_ttl,
        )
        self._sessions[thread_id] = session
        return session

    def get_session(self, chat_id: int, topic_id: Optional[int] = None) -> Optional[ConversationSession]:
        """Retrieves session if present without auto-creation."""
        thread_id = ConversationSession.build_thread_id(chat_id, topic_id)
        if thread_id in self._sessions:
            session = self._sessions[thread_id]
            if not session.is_expired():
                session.touch()
                self._sessions.move_to_end(thread_id)
                return session
            # Expired
            self._sessions.pop(thread_id, None)
        return None

    def record_incoming_message(self, message: Message) -> ConversationSession:
        """Records an incoming message from Telegram into its thread session."""
        chat_id = message.chat.id
        topic_id = message.message_thread_id
        session = self.get_or_create_session(chat_id, topic_id)

        conv_msg = ConversationMessage.from_message(message, is_bot=False)
        session.add_message(conv_msg)
        return session

    def record_outgoing_response(
        self,
        chat_id: int,
        text: str,
        topic_id: Optional[int] = None,
        message_id: int = 0,
        reply_to_id: Optional[int] = None,
    ) -> ConversationSession:
        """Records an outgoing bot response into the thread session."""
        session = self.get_or_create_session(chat_id, topic_id)
        conv_msg = ConversationMessage(
            message_id=message_id,
            sender_id=0,
            sender_name="Bot",
            text=text,
            timestamp=time.time(),
            is_bot=True,
            reply_to_id=reply_to_id,
        )
        session.add_message(conv_msg)
        return session

    def transition_thread(
        self,
        chat_id: int,
        topic_id: Optional[int],
        new_state: ThreadState,
    ) -> None:
        """Changes the state of a thread and notifies listeners."""
        session = self.get_or_create_session(chat_id, topic_id)
        session.transition_to(new_state)
        self._notify_listeners(session.thread_id, new_state)

    def add_state_listener(self, listener: Callable[[str, ThreadState], None]) -> None:
        """Registers a callback for thread state transitions."""
        self._listeners.append(listener)

    def _notify_listeners(self, thread_id: str, new_state: ThreadState) -> None:
        for listener in self._listeners:
            try:
                listener(thread_id, new_state)
            except Exception:
                continue

    def _evict_lru(self) -> None:
        """Evicts expired sessions first; if none expired, evicts oldest LRU session."""
        now = time.time()
        for tid, sess in list(self._sessions.items()):
            if sess.is_expired(now):
                del self._sessions[tid]
                return

        # Evict oldest
        self._sessions.popitem(last=False)

    def cleanup_expired(self) -> int:
        """Purges all expired sessions and returns count of removed items."""
        now = time.time()
        expired_keys = [k for k, s in self._sessions.items() if s.is_expired(now)]
        for k in expired_keys:
            del self._sessions[k]
        return len(expired_keys)

    @property
    def active_session_count(self) -> int:
        return len(self._sessions)
