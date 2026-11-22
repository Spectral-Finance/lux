"""
Unit tests for telegram_prisms — lux issue #62 acceptance criteria.

Run:  python3 -m pytest test_prisms.py -v
  or: python3 test_prisms.py        (stdlib-only fallback runner)

Tests use an injected fake transport so NO network calls are made.
Covers: bot auth/getMe, message send/edit/delete/forward/copy, media
send (photo/document/voice + bytes upload), inline + reply keyboards,
callback answers, webhook set/delete/info, getUpdates, update dispatch,
rate-limit 429 retry (parameters.retry_after), 404/403/400 error mapping,
token manager (masking/rotation/env/file), event emission, and persistence.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from telegram_prisms import (  # noqa: E402
    BotPrism,
    EventEmitter,
    ForbiddenError,
    InMemoryPersistence,
    JsonFilePersistence,
    KeyboardPrism,
    MediaPrism,
    MessagePrism,
    NotFoundError,
    RateLimitedError,
    RateLimiter,
    ServerError,
    TelegramAPIError,
    TelegramHTTP,
    TokenManager,
    UpdatePrism,
    WebhookPrism,
)


# --------------------------------------------------------------------------- #
# Fake transport
# --------------------------------------------------------------------------- #
class FakeTransport:
    """Records calls and returns queued (status, headers, body) responses."""

    def __init__(self, responses=None):
        self.calls = []
        self._responses = list(responses or [])

    def __call__(self, method, url, headers, body):
        self.calls.append((method, url, headers, body))
        if self._responses:
            return self._responses.pop(0)
        return 200, {}, b'{"ok": true, "result": true}'


def _ok(result):
    """Build a 200 Telegram success envelope."""
    import json
    return (200, {}, json.dumps({"ok": True, "result": result}).encode())


def _err(code, description, **extra):
    """Build a Telegram error envelope."""
    import json
    payload = {"ok": False, "error_code": code, "description": description}
    payload.update(extra)
    return (code, {}, json.dumps(payload).encode())


def _http(transport, token="123456:test-token"):
    # sleep_fn is a no-op so retry tests don't actually wait.
    return TelegramHTTP(token, transport=transport, sleep_fn=lambda s: None)


# --------------------------------------------------------------------------- #
# TokenManager
# --------------------------------------------------------------------------- #
def test_token_manager_masking_and_rotation():
    tm = TokenManager("123456:super-secret-token")
    assert "super-secret" not in repr(tm)
    assert "super-secret" not in str(tm)
    assert tm.masked().startswith("123456")
    assert tm.resolve() == "123456:super-secret-token"
    tm.rotate("999:new-token")
    assert tm.resolve() == "999:new-token"


def test_token_manager_explicit_override():
    tm = TokenManager("abc:def")
    assert tm.resolve("explicit:token") == "explicit:token"


def test_token_manager_env(monkeypatch=None):
    os.environ["TELEGRAM_BOT_TOKEN"] = "env:token"
    try:
        tm = TokenManager()
        assert tm.resolve() == "env:token"
    finally:
        del os.environ["TELEGRAM_BOT_TOKEN"]


def test_token_manager_missing_raises():
    os.environ.pop("TELEGRAM_BOT_TOKEN", None)
    tm = TokenManager()
    try:
        tm.resolve()
        assert False, "expected TelegramAPIError"
    except TelegramAPIError:
        pass


def test_token_manager_file(tmp_path=None):
    import tempfile
    fd, path = tempfile.mkstemp()
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write("file:token\n")
        tm = TokenManager(token_file=path)
        assert tm.resolve() == "file:token"
    finally:
        os.unlink(path)


# --------------------------------------------------------------------------- #
# BotPrism
# --------------------------------------------------------------------------- #
def test_get_me():
    t = FakeTransport([_ok({"id": 42, "username": "lux_bot",
                            "first_name": "Lux"})])
    events = EventEmitter()
    seen = []
    events.on("Bot.authenticated", lambda **k: seen.append(k))
    p = BotPrism(_http(t), events=events)
    me = p.get_me()
    assert me["id"] == 42
    assert "/bot123456:test-token/getMe" in t.calls[0][1]
    assert seen and seen[0]["bot_id"] == 42


def test_bot_commands_and_logout():
    t = FakeTransport([_ok([{"command": "start"}]),   # getMyCommands
                       _ok(True),                    # setMyCommands
                       _ok(True),                    # deleteMyCommands
                       _ok(True)])                   # logOut
    p = BotPrism(_http(t))
    assert p.get_my_commands()[0]["command"] == "start"
    assert p.set_my_commands([{"command": "start"}]) is True
    assert p.delete_my_commands() is True
    assert p.log_out() is True


# --------------------------------------------------------------------------- #
# MessagePrism
# --------------------------------------------------------------------------- #
def test_send_message():
    t = FakeTransport([_ok({"message_id": 100})])
    p = MessagePrism(_http(t))
    msg = p.send_message("chat1", "hello", parse_mode="Markdown")
    assert msg["message_id"] == 100
    body = t.calls[0][3]
    assert b"sendMessage" not in body  # method is in URL
    assert b'"chat_id": "chat1"' in body
    assert b'"text": "hello"' in body


def test_send_message_drops_none():
    t = FakeTransport([_ok({"message_id": 1})])
    p = MessagePrism(_http(t))
    p.send_message("c", "hi")
    body = t.calls[0][3]
    assert b"reply_markup" not in body
    assert b"disable_notification" not in body


def test_reply_and_edit_and_delete():
    t = FakeTransport([_ok({"message_id": 2}),   # reply
                       _ok({"message_id": 2}),   # edit
                       _ok(True)])               # delete
    p = MessagePrism(_http(t))
    p.reply("c", 1, "replying")
    assert b'"reply_to_message_id": 1' in t.calls[0][3]
    p.edit_message_text("c", 2, "edited")
    assert "editMessageText" in t.calls[1][1]
    assert p.delete_message("c", 2) is True
    assert "deleteMessage" in t.calls[2][1]


def test_edit_inline_message():
    t = FakeTransport([_ok(True)])
    p = MessagePrism(_http(t))
    p.edit_message_text(None, None, "x", inline_message_id="inline1")
    body = t.calls[0][3]
    assert b'"inline_message_id": "inline1"' in body
    assert b'"chat_id"' not in body


def test_forward_and_copy():
    t = FakeTransport([_ok({"message_id": 3}), _ok({"message_id": 4})])
    p = MessagePrism(_http(t))
    p.forward_message("c", "src", 5)
    assert "forwardMessage" in t.calls[0][1]
    p.copy_message("c", "src", 5)
    assert "copyMessage" in t.calls[1][1]


# --------------------------------------------------------------------------- #
# MediaPrism
# --------------------------------------------------------------------------- #
def test_send_photo_file_id():
    t = FakeTransport([_ok({"message_id": 10})])
    p = MediaPrism(_http(t))
    msg = p.send_photo("c", "AgACAgIAAx", caption="cap")
    assert msg["message_id"] == 10
    assert "sendPhoto" in t.calls[0][1]
    body = t.calls[0][3]
    assert b'"photo": "AgACAgIAAx"' in body
    assert b'"caption": "cap"' in body


def test_send_photo_bytes_upload():
    t = FakeTransport([_ok({"message_id": 11})])
    p = MediaPrism(_http(t))
    p.send_photo("c", b"\x89PNG\r\n", caption="raw")
    headers = t.calls[0][2]
    assert "multipart/form-data" in headers["Content-Type"]
    body = t.calls[0][3]
    assert b'name="photo"' in body
    assert b"\x89PNG" in body


def test_send_document_voice_audio_video():
    t = FakeTransport([_ok({"message_id": 1}), _ok({"message_id": 2}),
                       _ok({"message_id": 3}), _ok({"message_id": 4})])
    p = MediaPrism(_http(t))
    p.send_document("c", "docid")
    p.send_voice("c", "voiceid", duration=5)
    p.send_audio("c", "audioid")
    p.send_video("c", "videoid")
    assert "sendDocument" in t.calls[0][1]
    assert "sendVoice" in t.calls[1][1]
    assert b'"duration": 5' in t.calls[1][3]
    assert "sendAudio" in t.calls[2][1]
    assert "sendVideo" in t.calls[3][1]


# --------------------------------------------------------------------------- #
# KeyboardPrism
# --------------------------------------------------------------------------- #
def test_inline_keyboard_builder():
    kb = KeyboardPrism.inline_keyboard([
        [KeyboardPrism.inline_button("A", callback_data="a")],
        [KeyboardPrism.inline_button("B", url="https://x")],
    ])
    assert kb["inline_keyboard"][0][0]["callback_data"] == "a"
    assert kb["inline_keyboard"][1][0]["url"] == "https://x"


def test_reply_keyboard_builder():
    kb = KeyboardPrism.reply_keyboard([[{"text": "Yes"}]])
    assert kb["keyboard"] == [[{"text": "Yes"}]]
    assert kb["resize_keyboard"] is True
    rm = KeyboardPrism.remove_reply_keyboard()
    assert rm["remove_keyboard"] is True


def test_answer_callback_query():
    t = FakeTransport([_ok(True)])
    p = KeyboardPrism(_http(t))
    assert p.answer_callback_query("cbq1", text="done") is True
    assert "answerCallbackQuery" in t.calls[0][1]
    assert b'"callback_query_id": "cbq1"' in t.calls[0][3]


def test_set_chat_menu_button():
    t = FakeTransport([_ok(True)])
    p = KeyboardPrism(_http(t))
    assert p.set_chat_menu_button("c", {"type": "commands"}) is True


# --------------------------------------------------------------------------- #
# WebhookPrism
# --------------------------------------------------------------------------- #
def test_set_and_delete_webhook():
    t = FakeTransport([_ok(True), _ok(True), _ok({"url": "https://hook"})])
    p = WebhookPrism(_http(t))
    assert p.set_webhook("https://hook", secret_token="s3cr3t") is True
    assert b'"url": "https://hook"' in t.calls[0][3]
    assert p.delete_webhook(drop_pending_updates=True) is True
    info = p.get_webhook_info()
    assert info["url"] == "https://hook"


def test_set_webhook_with_certificate():
    t = FakeTransport([_ok(True)])
    p = WebhookPrism(_http(t))
    p.set_webhook("https://hook", certificate=b"CERT")
    assert "multipart/form-data" in t.calls[0][2]["Content-Type"]


def test_get_updates():
    t = FakeTransport([_ok([{"update_id": 1}, {"update_id": 2}])])
    p = WebhookPrism(_http(t))
    ups = p.get_updates(offset=0, limit=10, timeout=30)
    assert len(ups) == 2
    assert b'"timeout": 30' in t.calls[0][3]


# --------------------------------------------------------------------------- #
# UpdatePrism
# --------------------------------------------------------------------------- #
def test_update_dispatch():
    t = FakeTransport()
    p = UpdatePrism(_http(t))
    got = []
    p.on_message(lambda u: got.append(u["message"]["text"]))
    p.on_callback_query(lambda u: got.append("cb"))
    p.process_update({"update_id": 1, "message": {"text": "hi"}})
    p.process_update({"update_id": 2, "callback_query": {"id": "x"}})
    assert got == ["hi", "cb"]


def test_update_handler_error_isolated():
    t = FakeTransport()
    p = UpdatePrism(_http(t))
    p.on_message(lambda u: (_ for _ in ()).throw(RuntimeError("boom")))
    results = p.process_update({"update_id": 1, "message": {}})
    assert results == []  # error isolated, no crash


def test_update_poll_advances_offset():
    t = FakeTransport([_ok([{"update_id": 5, "message": {"text": "x"}}])])
    p = UpdatePrism(_http(t))
    got = []
    p.on_message(lambda u: got.append(u))
    n = p.poll(timeout=0)
    assert n == 1
    assert p._offset == 6
    assert b'"offset": 6' not in t.calls[0][3]  # offset was None on first poll


def test_update_classify_unknown():
    assert UpdatePrism.classify({"weird": 1}) is None


# --------------------------------------------------------------------------- #
# Rate limiting + retry
# --------------------------------------------------------------------------- #
def test_rate_limit_429_retry_parameters():
    # First call 429 with parameters.retry_after: 0, second succeeds.
    t = FakeTransport([
        (429, {}, b'{"ok": false, "error_code": 429, '
                    b'"parameters": {"retry_after": 0}}'),
        _ok({"message_id": 1}),
    ])
    h = _http(t)
    result = h.request("sendMessage", {"chat_id": "c", "text": "x"})
    assert result["message_id"] == 1
    assert len(t.calls) == 2


def test_rate_limited_after_max_retries():
    t = FakeTransport([
        (429, {}, b'{"ok": false, "parameters": {"retry_after": 0}}')] * 7)
    h = TelegramHTTP("tok", transport=t, max_retries=3, sleep_fn=lambda s: None)
    try:
        h.request("sendMessage", {})
        assert False, "expected RateLimitedError"
    except RateLimitedError as e:
        assert e.retry_after == 0


def test_server_error_retry_then_success():
    t = FakeTransport([
        (500, {}, b'{"ok": false, "error_code": 500}'),
        _ok({"ok": True}),
    ])
    h = _http(t)
    result = h.request("getMe")
    assert result["ok"] is True
    assert len(t.calls) == 2


def test_server_error_after_max_retries():
    t = FakeTransport([(502, {}, b'{"ok": false}')] * 7)
    h = TelegramHTTP("tok", transport=t, max_retries=2, sleep_fn=lambda s: None)
    try:
        h.request("getMe")
        assert False, "expected ServerError"
    except ServerError:
        pass


def test_error_mapping_404_403_400():
    h404 = _http(FakeTransport([_err(404, "Not Found")]))
    try:
        h404.request("getMe")
        assert False
    except NotFoundError:
        pass
    h403 = _http(FakeTransport([_err(403, "Forbidden: bot was blocked")]))
    try:
        h403.request("sendMessage", {})
        assert False
    except ForbiddenError:
        pass
    h400 = _http(FakeTransport([_err(400, "Bad Request: chat not found")]))
    try:
        h400.request("sendMessage", {})
        assert False
    except TelegramAPIError as e:
        assert e.status == 400
        assert "Bad Request" in e.message


def test_retry_after_parsing():
    assert TelegramHTTP._retry_after(
        b'{"parameters": {"retry_after": 42}}') == 42
    assert TelegramHTTP._retry_after(b'{"retry_after": 7}') == 7
    assert TelegramHTTP._retry_after(b'not json') == 1.0


def test_rate_limiter_bucket():
    rl = RateLimiter()
    rl.update_from_headers("POST getMe", {"X-RateLimit-Limit": "5",
                                          "X-RateLimit-Remaining": "5"})
    for _ in range(5):
        rl.acquire("POST getMe")
    b = rl._bucket("POST getMe")
    assert b.tokens < 1.0


def test_rate_limiter_pause():
    rl = RateLimiter()
    rl.pause("POST x", 100)
    b = rl._bucket("POST x")
    assert b.tokens == 0.0
    assert b.updated_at > 0


# --------------------------------------------------------------------------- #
# Persistence
# --------------------------------------------------------------------------- #
def test_inmemory_persistence():
    p = InMemoryPersistence()
    p.set("k", {"v": 1})
    assert p.get("k") == {"v": 1}
    p.delete("k")
    assert p.get("k", "default") == "default"


def test_jsonfile_persistence():
    import tempfile
    fd, path = tempfile.mkstemp()
    os.close(fd)
    try:
        p = JsonFilePersistence(path)
        p.set("token:1", {"a": 1})
        p2 = JsonFilePersistence(path)
        assert p2.get("token:1") == {"a": 1}
        p2.delete("token:1")
        p3 = JsonFilePersistence(path)
        assert p3.get("token:1") is None
    finally:
        os.unlink(path)


# --------------------------------------------------------------------------- #
# Event emitter
# --------------------------------------------------------------------------- #
def test_event_emitter_on_off_emit():
    e = EventEmitter()
    seen = []
    h = lambda **k: seen.append(k)  # noqa: E731
    e.on("X.y", h)
    e.emit("X.y", a=1)
    assert seen == [{"a": 1}]
    e.off("X.y", h)
    e.emit("X.y", a=2)
    assert len(seen) == 1


def test_event_emitter_isolates_failures():
    e = EventEmitter()
    e.on("X.y", lambda **k: (_ for _ in ()).throw(ValueError()))
    e.emit("X.y")  # must not raise


# --------------------------------------------------------------------------- #
# stdlib-only fallback runner
# --------------------------------------------------------------------------- #
def _run_all():
    tests = [v for k, v in sorted(globals().items())
             if k.startswith("test_") and callable(v)]
    passed = 0
    failed = 0
    for t in tests:
        try:
            t()
            print(f"  PASS {t.__name__}")
            passed += 1
        except Exception as e:  # noqa: BLE001
            print(f"  FAIL {t.__name__}: {e}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed, {len(tests)} total")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    try:
        import pytest  # noqa: F401
        sys.exit(_run_all())
    except ImportError:
        sys.exit(_run_all())