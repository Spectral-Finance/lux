"""
Unit tests for discord_prisms — lux issue #57 acceptance criteria.

Run:  python3 -m pytest test_prisms.py -v
  or: python3 test_prisms.py        (stdlib-only fallback runner)

Tests use an injected fake transport so NO network calls are made.
Covers: message CRUD + bulk-delete bounds, channel CRUD + permissions +
archive, moderation (filter/timeout/ban/warnings), event scheduling +
reminders, rate-limit 429 retry, 404/403 error mapping, event emission,
and persistence.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from discord_prisms import (  # noqa: E402
    ChannelManagementPrism,
    DiscordHTTP,
    EventEmitter,
    EventHandlingPrism,
    ForbiddenError,
    InMemoryPersistence,
    MessageManagementPrism,
    ModerationPrism,
    NotFoundError,
    RateLimitedError,
    RateLimiter,
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
        self.calls.append((method, url, body))
        if self._responses:
            return self._responses.pop(0)
        return 200, {}, b"{}"


def _http(transport, token="test-token"):
    # sleep_fn is a no-op so retry tests don't actually wait.
    return DiscordHTTP(token, transport=transport, sleep_fn=lambda s: None)


# --------------------------------------------------------------------------- #
# MessageManagementPrism
# --------------------------------------------------------------------------- #
def test_create_message():
    t = FakeTransport([(200, {}, b'{"id": "m1"}')])
    events = EventEmitter()
    seen = []
    events.on("MessageManagement.message_created", lambda **k: seen.append(k))
    p = MessageManagementPrism(_http(t), events=events)
    msg = p.create_message("c1", "hello")
    assert msg["id"] == "m1"
    assert t.calls[0][0] == "POST"
    assert "/channels/c1/messages" in t.calls[0][1]
    assert seen and seen[0]["message_id"] == "m1"


def test_edit_and_delete_message():
    t = FakeTransport([(200, {}, b'{"id": "m1"}'),
                       (204, {}, b"")])
    p = MessageManagementPrism(_http(t))
    p.edit_message("c1", "m1", "edited")
    assert t.calls[0][0] == "PATCH"
    p.delete_message("c1", "m1", reason="spam")
    assert t.calls[1][0] == "DELETE"


def test_bulk_delete_bounds():
    t = FakeTransport()
    p = MessageManagementPrism(_http(t))
    # too few
    try:
        p.bulk_delete("c1", ["only-one"])
        assert False, "expected ValueError for <2 ids"
    except ValueError:
        pass
    # too many
    try:
        p.bulk_delete("c1", [str(i) for i in range(101)])
        assert False, "expected ValueError for >100 ids"
    except ValueError:
        pass
    # valid
    t2 = FakeTransport([(204, {}, b"")])
    p2 = MessageManagementPrism(_http(t2))
    p2.bulk_delete("c1", ["1", "2", "3"])
    assert t2.calls[0][0] == "POST"
    assert "bulk-delete" in t2.calls[0][1]


def test_get_history():
    t = FakeTransport([(200, {}, b'[{"id":"a"},{"id":"b"}]')])
    p = MessageManagementPrism(_http(t))
    msgs = p.get_history("c1", limit=10)
    assert len(msgs) == 2


# --------------------------------------------------------------------------- #
# ChannelManagementPrism
# --------------------------------------------------------------------------- #
def test_channel_crud():
    t = FakeTransport([(200, {}, b'{"id":"ch1"}'),   # create
                       (200, {}, b'{"id":"ch1"}'),   # update
                       (200, {}, b'{"id":"ch1"}')])  # delete
    p = ChannelManagementPrism(_http(t))
    ch = p.create_channel("g1", "general", topic="hi")
    assert ch["id"] == "ch1"
    p.update_channel("ch1", name="renamed")
    assert t.calls[1][0] == "PATCH"
    p.delete_channel("ch1")
    assert t.calls[2][0] == "DELETE"


def test_channel_permissions_and_archive():
    t = FakeTransport([(200, {}, b"{}"),          # set_permissions
                       (200, {}, b'{"id":"ch1"}'),  # archive (update)
                       (200, {}, b'{"id":"ch1"}')]) # unarchive (update)
    p = ChannelManagementPrism(_http(t))
    p.set_permissions("ch1", "role1", allow=1024, deny=0, permission_type=0)
    assert t.calls[0][0] == "PUT"
    p.archive_channel("ch1")
    p.unarchive_channel("ch1")
    assert t.calls[1][2] == b'{"archived": true}'
    assert t.calls[2][2] == b'{"archived": false}'


# --------------------------------------------------------------------------- #
# ModerationPrism
# --------------------------------------------------------------------------- #
def test_content_filter():
    p = ModerationPrism(_http(FakeTransport()), banned_words=["damn", "crap"])
    assert p.filter_content("this is clean")["clean"] is True
    verdict = p.filter_content("what the crap")
    assert verdict["clean"] is False
    assert "crap" in verdict["matched"]


def test_timeout_member():
    t = FakeTransport([(200, {}, b"{}")])
    p = ModerationPrism(_http(t))
    p.timeout_member("g1", "u1", 3600, reason="spamming")
    body = t.calls[0][2]
    assert b"communication_disabled_until" in body
    assert b"PT1H" in body  # 3600s -> PT1H


def test_timeout_rejects_nonpositive():
    p = ModerationPrism(_http(FakeTransport()))
    try:
        p.timeout_member("g1", "u1", 0)
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_ban_unban():
    t = FakeTransport([(204, {}, b""), (204, {}, b"")])
    p = ModerationPrism(_http(t))
    p.ban_member("g1", "u1", reason="abuse")
    assert t.calls[0][0] == "PUT"
    p.unban_member("g1", "u1")
    assert t.calls[1][0] == "DELETE"


def test_warning_system():
    p = ModerationPrism(_http(FakeTransport()))
    p.add_warning("g1", "u1", "first warning", moderator_id="mod1")
    p.add_warning("g1", "u1", "second warning")
    warnings = p.get_warnings("g1", "u1")
    assert len(warnings) == 2
    p.clear_warnings("g1", "u1")
    assert p.get_warnings("g1", "u1") == []


# --------------------------------------------------------------------------- #
# EventHandlingPrism
# --------------------------------------------------------------------------- #
def test_schedule_event_persists():
    t = FakeTransport([(200, {}, b'{"id":"ev1"}')])
    p = EventHandlingPrism(_http(t))
    ev = p.schedule_event("g1", "Standup", "2026-12-01T10:00:00Z",
                          channel_id="c1")
    assert ev["id"] == "ev1"
    assert p.persistence.get("event:ev1")["id"] == "ev1"


def test_reminders_due():
    p = EventHandlingPrism(_http(FakeTransport()))
    p.add_reminder("ev1", remind_at_epoch=1000)
    p.add_reminder("ev1", remind_at_epoch=9999999)
    due = p.due_reminders(now_epoch=2000)
    assert len(due) == 1
    assert due[0]["remind_at"] == 1000


def test_notify():
    t = FakeTransport([(200, {}, b'{"id":"m9"}')])
    p = EventHandlingPrism(_http(t))
    msg = p.notify("c1", "Event starting soon")
    assert msg["id"] == "m9"


# --------------------------------------------------------------------------- #
# Rate limiting + retry
# --------------------------------------------------------------------------- #
def test_rate_limit_429_retry():
    # First call 429 with Retry-After: 0, second succeeds.
    t = FakeTransport([
        (429, {"Retry-After": "0"}, b'{"retry_after": 0}'),
        (200, {}, b'{"id":"ok"}'),
    ])
    h = _http(t)
    result = h.request("GET", "/guilds/g1")
    assert result["id"] == "ok"
    assert len(t.calls) == 2


def test_rate_limited_after_max_retries():
    t = FakeTransport([(429, {"Retry-After": "0"}, b'{"retry_after":0}')] * 7)
    h = DiscordHTTP("tok", transport=t, max_retries=3, sleep_fn=lambda s: None)
    try:
        h.request("GET", "/x")
        assert False, "expected RateLimitedError"
    except RateLimitedError:
        pass


def test_error_mapping_404_403():
    h404 = _http(FakeTransport([(404, {}, b'{"message":"nope"}')]))
    try:
        h404.request("GET", "/missing")
        assert False
    except NotFoundError:
        pass
    h403 = _http(FakeTransport([(403, {}, b'{"message":"denied"}')]))
    try:
        h403.request("GET", "/forbidden")
        assert False
    except ForbiddenError:
        pass


def test_rate_limiter_bucket():
    rl = RateLimiter()
    rl.update_from_headers("GET /x", {"X-RateLimit-Limit": "5",
                                      "X-RateLimit-Remaining": "5"})
    # consume all 5 tokens without blocking
    for _ in range(5):
        rl.acquire("GET /x")
    # 6th would block; just assert bucket is drained
    b = rl._bucket("GET /x")
    assert b.tokens < 1.0


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