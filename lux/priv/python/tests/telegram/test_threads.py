"""
Unit tests for ThreadManager, ConversationSession, context trimming, and state machine.
"""

import time
import pytest
from lux.telegram.threads import (
    ConversationMessage,
    ConversationSession,
    ThreadManager,
    ThreadTransitionError,
)
from lux.telegram.types import (
    Chat,
    ChatType,
    Message,
    ThreadState,
    User,
)


def test_conversation_session_ring_buffer():
    session = ConversationSession(chat_id=100, max_history=3)
    for i in range(5):
        session.add_message(ConversationMessage(
            message_id=i, sender_id=1, sender_name="User", text=f"Message {i}"
        ))

    messages = session.get_messages()
    assert len(messages) == 3
    assert [m.message_id for m in messages] == [2, 3, 4]


def test_thread_state_transitions():
    session = ConversationSession(chat_id=100)
    assert session.state == ThreadState.ACTIVE

    session.transition_to(ThreadState.PAUSED)
    assert session.state == ThreadState.PAUSED

    session.transition_to(ThreadState.ACTIVE)
    assert session.state == ThreadState.ACTIVE

    session.transition_to(ThreadState.CLOSED)
    assert session.state == ThreadState.CLOSED

    # Invalid transition directly from CLOSED to PAUSED
    with pytest.raises(ThreadTransitionError):
        session.transition_to(ThreadState.PAUSED)


def test_context_window_trimming():
    session = ConversationSession(chat_id=100, max_history=10)
    session.add_message(ConversationMessage(1, 10, "Alice", "Short msg 1", is_bot=False))
    session.add_message(ConversationMessage(2, 0, "Bot", "Short bot response", is_bot=True))
    session.add_message(ConversationMessage(3, 10, "Alice", "A very long message " * 20, is_bot=False))
    session.add_message(ConversationMessage(4, 0, "Bot", "Final response", is_bot=True))

    trimmed = session.trim_context_window(max_tokens=60, system_prompt="System prompt here")
    assert len(trimmed) >= 2
    assert trimmed[0]["role"] == "system"
    assert trimmed[0]["content"] == "System prompt here"
    assert trimmed[-1]["role"] == "assistant"
    assert trimmed[-1]["content"] == "Final response"


def test_thread_manager_lru_and_capacity():
    tm = ThreadManager(capacity=2, default_ttl=3600.0)
    s1 = tm.get_or_create_session(chat_id=1)
    s2 = tm.get_or_create_session(chat_id=2)
    assert tm.active_session_count == 2

    # Touch s1 so s2 becomes LRU
    tm.get_session(chat_id=1)

    # Add s3 -> s2 should be evicted
    s3 = tm.get_or_create_session(chat_id=3)
    assert tm.active_session_count == 2
    assert tm.get_session(chat_id=1) is not None
    assert tm.get_session(chat_id=3) is not None
    assert tm.get_session(chat_id=2) is None


def test_thread_manager_record_incoming_and_outgoing():
    tm = ThreadManager()
    user = User(id=55, first_name="Bob")
    chat = Chat(id=777, type=ChatType.GROUP)
    msg = Message(message_id=10, chat=chat, from_user=user, text="Hello bot", message_thread_id=42)

    sess = tm.record_incoming_message(msg)
    assert sess.topic_id == 42
    assert sess.chat_id == 777
    assert len(sess.history) == 1

    tm.record_outgoing_response(chat_id=777, text="Hello Bob!", topic_id=42, message_id=11)
    sess_updated = tm.get_session(chat_id=777, topic_id=42)
    assert len(sess_updated.history) == 2
    assert sess_updated.history[-1].is_bot is True
