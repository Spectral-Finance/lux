"""
Unit tests for CallbackProcessor, compact payload codecs, pagination, and response acknowledgments.
"""

import pytest
from lux.telegram.callbacks import (
    CallbackAnswer,
    CallbackDataPayload,
    CallbackPayloadTooLargeError,
    CallbackProcessor,
)
from lux.telegram.types import (
    CallbackQuery,
    PermissionLevel,
    User,
)


@pytest.fixture
def processor():
    return CallbackProcessor()


@pytest.fixture
def dummy_callback_query():
    user = User(id=123, first_name="Trader", username="trader1")
    return CallbackQuery(id="cq_999", from_user=user, data="trade:ETH:buy")


def test_callback_encode_decode(processor):
    encoded = processor.encode("swap", target="pool1", item_id="100", params={"slippage": "0.5"})
    assert encoded == "swap:pool1:100:slippage=0.5"

    decoded = processor.decode(encoded)
    assert decoded.action == "swap"
    assert decoded.target == "pool1"
    assert decoded.item_id == "100"
    assert decoded.params["slippage"] == "0.5"


def test_callback_payload_too_large_enforcement(processor):
    huge_str = "a" * 70
    with pytest.raises(CallbackPayloadTooLargeError):
        processor.encode("action", target=huge_str)


def test_pagination_keyboard_and_codec(processor):
    kb = processor.create_pagination_keyboard("orders", current_page=3, total_pages=10, page_size=5)
    row = kb.inline_keyboard[0]
    assert len(row) == 5  # [⏮ 1] [◀ Prev] [· 3/10 ·] [Next ▶] [⏭ 10]

    assert row[0].text == "⏮ 1"
    assert "page:orders:" in row[0].callback_data

    # Decode pagination button data
    decoded_page = processor.decode(row[3].callback_data)  # Next button (page 4)
    assert decoded_page.action == "page"
    assert decoded_page.target == "orders"
    assert decoded_page.params["p"] == "4"


def test_callback_handler_dispatch_and_answer(processor, dummy_callback_query):
    executed = []

    @processor.on("trade")
    def handle_trade(cb: CallbackQuery, payload: CallbackDataPayload):
        executed.append((payload.target, payload.item_id))
        return "Order submitted"

    answer, res = processor.process(dummy_callback_query)
    assert executed == [("ETH", "buy")]
    assert answer is not None
    assert answer.text == "Order submitted"
    assert answer.callback_query_id == "cq_999"


def test_callback_permission_check(processor, dummy_callback_query):
    @processor.on("trade", permission=PermissionLevel.ADMIN)
    def handle_admin_trade(cb: CallbackQuery, payload: CallbackDataPayload):
        return "Admin success"

    answer, res = processor.process(dummy_callback_query, user_permission=PermissionLevel.USER)
    assert answer is not None
    assert answer.show_alert is True
    assert "permission" in answer.text.lower()


def test_callback_answer_to_api_payload():
    ans = CallbackAnswer(callback_query_id="123", text="Done", show_alert=True, cache_time=300)
    payload = ans.to_api_payload()
    assert payload["callback_query_id"] == "123"
    assert payload["text"] == "Done"
    assert payload["show_alert"] is True
    assert payload["cache_time"] == 300
