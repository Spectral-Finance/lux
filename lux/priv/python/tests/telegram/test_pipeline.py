"""
Unit tests for TelegramPipeline end-to-end update processing.
"""

import pytest
from lux.telegram.pipeline import TelegramPipeline
from lux.telegram.types import (
    CallbackQuery,
    Chat,
    ChatType,
    IntentCategory,
    Message,
    ParsedCommand,
    Update,
    User,
)


@pytest.fixture
def pipeline():
    pipe = TelegramPipeline(bot_username="SpectralBot", secret_key="test-key")

    @pipe.command_router.command("ping")
    def handle_ping(ctx):
        return "pong"

    @pipe.command_router.command("long_report")
    def handle_long_report(ctx):
        # Generate 5,000 characters to trigger splitting
        return "Header Analysis\n\n" + ("Section content line.\n" * 250)

    @pipe.callback_processor.on("confirm")
    def handle_confirm(cb, payload):
        return "Confirmed successfully"

    @pipe.on_message
    def handle_convo(msg, analysis, extra):
        return f"Echo intent: {analysis.intent}"

    return pipe


def test_pipeline_command_processing(pipeline):
    raw_update = {
        "update_id": 1001,
        "message": {
            "message_id": 50,
            "date": 1600000000,
            "chat": {"id": 12345, "type": "private"},
            "from": {"id": 999, "first_name": "Alice"},
            "text": "/ping",
        },
    }

    result = pipeline.process_raw_update(raw_update)
    assert result.success is True
    assert result.action_taken == "command"
    assert len(result.response_payloads) == 1
    assert result.response_payloads[0]["method"] == "sendMessage"
    assert result.response_payloads[0]["params"]["text"] == "pong"


def test_pipeline_long_response_splitting(pipeline):
    raw_update = {
        "update_id": 1002,
        "message": {
            "message_id": 51,
            "date": 1600000000,
            "chat": {"id": 12345, "type": "private"},
            "from": {"id": 999, "first_name": "Alice"},
            "text": "/long_report",
        },
    }

    result = pipeline.process_raw_update(raw_update)
    assert result.success is True
    # Should be split into 2 or more chunks
    assert len(result.response_payloads) >= 2
    for payload in result.response_payloads:
        assert payload["method"] == "sendMessage"
        assert len(payload["params"]["text"]) <= 4096


def test_pipeline_callback_processing(pipeline):
    raw_update = {
        "update_id": 1003,
        "callback_query": {
            "id": "cq_12345",
            "from": {"id": 999, "first_name": "Alice"},
            "data": "confirm:order:777",
        },
    }

    result = pipeline.process_raw_update(raw_update)
    assert result.success is True
    assert result.action_taken == "callback_query"
    assert len(result.response_payloads) >= 1
    assert result.response_payloads[0]["method"] == "answerCallbackQuery"
    assert result.response_payloads[0]["params"]["text"] == "Confirmed successfully"


def test_pipeline_conversational_message_and_analysis(pipeline):
    raw_update = {
        "update_id": 1004,
        "message": {
            "message_id": 52,
            "date": 1600000000,
            "chat": {"id": 12345, "type": "private"},
            "from": {"id": 999, "first_name": "Alice"},
            "text": "What is the price of $LUX and $ETH?",
        },
    }

    result = pipeline.process_raw_update(raw_update)
    assert result.success is True
    assert result.action_taken == "conversation"
    assert result.analysis is not None
    assert result.analysis.intent in (IntentCategory.QUERY, IntentCategory.TRADING, "query", "trading")
    assert "LUX" in result.analysis.extracted_entities["crypto_tickers"]
    assert "ETH" in result.analysis.extracted_entities["crypto_tickers"]
    assert len(result.response_payloads) == 1
    assert "Echo intent:" in result.response_payloads[0]["params"]["text"]


def test_pipeline_deep_link_processing(pipeline):
    raw_update = {
        "update_id": 1005,
        "message": {
            "message_id": 53,
            "date": 1600000000,
            "chat": {"id": 12345, "type": "private"},
            "from": {"id": 999, "first_name": "Alice"},
            "text": "/start ref_4455_campaignA",
        },
    }

    result = pipeline.process_raw_update(raw_update)
    assert result.success is True
    assert result.action_taken == "deep_link"
