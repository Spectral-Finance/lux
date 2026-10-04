"""
Unit tests for ReplyManager, quote generation, safe chunking, and error cards.
"""

import pytest
from lux.telegram.replies import (
    MAX_MESSAGE_LENGTH,
    ReplyManager,
)
from lux.telegram.types import (
    Chat,
    ChatType,
    Message,
    ParseMode,
    User,
)


def test_reply_chain_tracking_and_root_detection():
    rm = ReplyManager()
    user = User(id=1, first_name="Alice")
    chat = Chat(id=100, type=ChatType.PRIVATE)

    # Message 1 (Root)
    m1 = Message(message_id=1, chat=chat, from_user=user, text="Root message")
    rm.track_reply(m1)

    # Message 2 (Child of 1)
    m2 = Message(message_id=2, chat=chat, from_user=user, text="Reply 1", reply_to_message=m1)
    rm.track_reply(m2)

    # Message 3 (Child of 2)
    m3 = Message(message_id=3, chat=chat, from_user=user, text="Reply 2", reply_to_message=m2)
    rm.track_reply(m3)

    assert rm.get_root_message_id(3) == 1
    assert rm.get_root_message_id(2) == 1
    assert rm.get_reply_depth(3) == 2
    assert rm.get_reply_depth(1) == 0


def test_generate_quote():
    raw_quote = "This is a very long original message that discusses high frequency automated trading algorithms."
    quote = ReplyManager.generate_quote(raw_quote, author="Alice", max_length=50)
    assert "Alice" in quote
    assert quote.startswith(">")


def test_split_message_under_limit():
    short_text = "This is a short message well under 4096 characters."
    chunks = ReplyManager.split_message(short_text, max_limit=100)
    assert len(chunks) == 1
    assert chunks[0] == short_text


def test_split_message_over_limit_with_code_blocks():
    # Long text with code block spanning boundary
    code_content = "x = 1\ny = 2\n" * 15
    long_text = f"Intro header\n\n```python\n{code_content}```\n\nOutro text"
    chunks = ReplyManager.split_message(long_text, max_limit=120)

    assert len(chunks) > 1
    # Every chunk should be under max_limit + buffer
    for chunk in chunks:
        assert len(chunk) <= 150
        # If chunk contains code block start, check that ``` are balanced
        assert chunk.count("```") % 2 == 0


def test_frame_response():
    framed = ReplyManager.frame_response(
        body="Order executed successfully for 1.5 ETH",
        title="Execution Report",
        status_icon="✅",
        footer="Tx: 0x123",
        parse_mode=ParseMode.MARKDOWN_V2,
    )
    assert "Execution Report" in framed
    assert "Order executed successfully" in framed
    assert "0x123" in framed


def test_create_error_response():
    msg, markup = ReplyManager.create_error_response(
        error_message="Insufficient wallet balance",
        error_code="ERR_INSUFFICIENT_FUNDS",
        suggestion="Deposit additional ETH to your account",
        retry_callback_data="trade:retry:123",
    )
    assert "Error" in msg
    assert "INSUFFICIENT" in msg
    assert "Insufficient wallet balance" in msg
    assert "Deposit additional ETH" in msg
    assert markup is not None
    assert markup.inline_keyboard[0][0].callback_data == "trade:retry:123"
