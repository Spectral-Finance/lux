"""
Unit tests for youtube_community_prisms — lux issue #70 acceptance criteria.

Run:  python3 -m pytest test_prisms.py -v
  or: python3 test_prisms.py        (stdlib-only fallback runner)

Tests use an injected fake transport so NO network calls are made.
Covers: community post scheduling/publishing/queue, comment listing + sentiment
+ spam + moderation + auto-reply, live chat moderation/bans/slow-mode,
member interaction tracking + segmentation, analytics + campaigns, rate-limit
429 retry, quota accounting, 404/403/400 error mapping, event emission, and
persistence.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from youtube_community_prisms import (  # noqa: E402
    AnalyticsPrism,
    AuthenticationError,
    CommentModerationPrism,
    CommunityPostPrism,
    EventEmitter,
    ForbiddenError,
    InMemoryPersistence,
    LiveChatPrism,
    MemberManagementPrism,
    NotFoundError,
    RateLimitedError,
    RateLimiter,
    ValidationError,
    YouTubeHTTP,
    analyze_sentiment,
    detect_spam,
    generate_response,
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


def _http(transport, token="test-key"):
    # sleep_fn is a no-op so retry tests don't actually wait.
    return YouTubeHTTP(token, transport=transport, sleep_fn=lambda s: None)


# --------------------------------------------------------------------------- #
# Analysis helpers
# --------------------------------------------------------------------------- #
def test_sentiment_positive():
    r = analyze_sentiment("This video is absolutely amazing and helpful, love it!")
    assert r["label"] == "positive"
    assert r["score"] > 0


def test_sentiment_negative():
    r = analyze_sentiment("This is terrible, boring and a complete waste of time")
    assert r["label"] == "negative"
    assert r["score"] < 0


def test_sentiment_neutral_and_negation():
    assert analyze_sentiment("the video is on the table")["label"] == "neutral"
    # "not good" should flip to negative
    r = analyze_sentiment("this is not good at all")
    assert r["label"] == "negative"


def test_spam_detection_links_and_phrases():
    spam = detect_spam("BUY NOW!!! click here https://spam.example.com make money")
    assert spam["spam"] is True
    assert spam["score"] >= 0.5
    clean = detect_spam("Great tutorial, thanks for explaining this clearly.")
    assert clean["spam"] is False


def test_response_generation_intents():
    q = generate_response("How do I set up the API key?")
    assert q["intent"] == "question"
    praise = generate_response("Love this, thank you so much!")
    assert praise["intent"] == "praise"
    complaint = generate_response("This is the worst clickbait ever")
    assert complaint["sentiment"] == "negative"


# --------------------------------------------------------------------------- #
# CommunityPostPrism
# --------------------------------------------------------------------------- #
def test_schedule_and_due_posts():
    p = CommunityPostPrism(_http(FakeTransport()))
    post = p.schedule_post("ch1", "New video Friday!", scheduled_for=1000)
    assert post["status"] == "scheduled"
    assert p.persistence.get("community_post:" + post["id"])["id"] == post["id"]
    # not due yet
    assert p.due_posts(now=500) == []
    # due now
    due = p.due_posts(now=1500)
    assert len(due) == 1 and due[0]["id"] == post["id"]


def test_publish_now_with_publisher():
    calls = {}

    def publisher(channel_id, post):
        calls["channel_id"] = channel_id
        return {"id": "yt_abc"}

    p = CommunityPostPrism(_http(FakeTransport()), publisher=publisher)
    post = p.publish_now("ch1", "Hello world")
    assert post["status"] == "published"
    assert post["id"] == "yt_abc"
    assert calls["channel_id"] == "ch1"


def test_process_due_posts_publishes():
    published = {}

    def publisher(channel_id, post):
        published["id"] = post["id"]
        return {}

    p = CommunityPostPrism(_http(FakeTransport()), publisher=publisher)
    p.schedule_post("ch1", "queued", scheduled_for=100)
    out = p.process_due_posts(now=200)
    assert len(out) == 1 and out[0]["status"] == "published"


def test_cancel_post_and_validation():
    p = CommunityPostPrism(_http(FakeTransport()))
    post = p.schedule_post("ch1", "text", scheduled_for=10)
    p.cancel_post(post["id"])
    assert p.get_post(post["id"])["status"] == "cancelled"
    try:
        p.schedule_post("ch1", "", scheduled_for=10)
        assert False, "expected ValidationError for empty content"
    except ValidationError:
        pass


# --------------------------------------------------------------------------- #
# CommentModerationPrism
# --------------------------------------------------------------------------- #
def test_list_comment_threads():
    t = FakeTransport([(200, {}, b'{"items":[{"id":"t1"},{"id":"t2"}]}')])
    p = CommentModerationPrism(_http(t))
    data = p.list_comment_threads(video_id="v1", max_results=5)
    assert len(data["items"]) == 2
    assert t.calls[0][0] == "GET"
    assert "commentThreads" in t.calls[0][1]
    assert "videoId=v1" in t.calls[0][1]


def test_analyze_thread():
    p = CommentModerationPrism(_http(FakeTransport()))
    thread = {
        "snippet": {
            "videoId": "v1",
            "topLevelComment": {
                "id": "c1",
                "snippet": {"textDisplay": "This is amazing, love it!",
                            "authorDisplayName": "alice"},
            },
        }
    }
    r = p.analyze_thread(thread)
    assert r["sentiment"]["label"] == "positive"
    assert r["comment_id"] == "c1"
    assert r["author"] == "alice"


def test_moderation_status_actions():
    t = FakeTransport([(200, {}, b"{}"), (200, {}, b"{}")])
    p = CommentModerationPrism(_http(t))
    p.hold_for_review("c1")
    assert t.calls[0][0] == "POST"
    assert "setModerationStatus" in t.calls[0][1]
    assert "heldForReview" in t.calls[0][1]
    p.reject_comment("c2", ban_user=True)
    assert "banAuthor=true" in t.calls[1][1]


def test_moderation_status_validation():
    p = CommentModerationPrism(_http(FakeTransport()))
    try:
        p.set_moderation_status("c1", "bogus")
        assert False, "expected ValidationError"
    except ValidationError:
        pass


def test_moderate_comment_auto_holds_spam():
    t = FakeTransport([(200, {}, b"{}")])
    p = CommentModerationPrism(_http(t), auto_hold_threshold=0.5)
    spam_text = "BUY NOW click here https://x.example.com make money fast"
    result = p.moderate_comment("c1", spam_text)
    assert result["decision"] == "held"
    assert result["analysis"]["spam"]["spam"] is True


def test_auto_reply_posts():
    t = FakeTransport([(200, {}, b'{"id":"r1"}')])
    p = CommentModerationPrism(_http(t))
    out = p.auto_reply("c1", "How do I do this?")
    assert out["suggestion"]["intent"] == "question"
    assert out["posted"]["id"] == "r1"
    assert t.calls[0][0] == "POST"


def test_moderation_log_persisted():
    p = CommentModerationPrism(_http(FakeTransport()))
    p.log_moderation("c1", {"decision": "held"})
    assert len(p.moderation_log()) == 1


# --------------------------------------------------------------------------- #
# LiveChatPrism
# --------------------------------------------------------------------------- #
def test_live_chat_list_and_moderate():
    t = FakeTransport([(200, {}, b'{"items":[{"id":"m1"}]}'),
                       (204, {}, b"")])
    p = LiveChatPrism(_http(t))
    data = p.list_messages("lc1")
    assert data["items"][0]["id"] == "m1"
    res = p.moderate_message("lc1", "m1",
                             text="BUY NOW click here https://x.example.com")
    assert res["deleted"] is True
    assert t.calls[1][0] == "DELETE"


def test_live_chat_ban_validation():
    t = FakeTransport([(200, {}, b"{}")])
    p = LiveChatPrism(_http(t))
    p.ban_user("lc1", "ch1", "user1", ban_duration_seconds=600)
    assert t.calls[0][0] == "POST"
    assert "liveChatMessages/ban" in t.calls[0][1]
    try:
        p.ban_user("lc1", "ch1", "user1", ban_duration_seconds=0)
        assert False, "expected ValidationError"
    except ValidationError:
        pass


def test_live_chat_slow_mode():
    p = LiveChatPrism(_http(FakeTransport()))
    p.set_slow_mode("lc1", 15)
    assert p.get_slow_mode("lc1") == 15
    p.set_slow_mode("lc1", 0)
    assert p.get_slow_mode("lc1") == 0


# --------------------------------------------------------------------------- #
# MemberManagementPrism
# --------------------------------------------------------------------------- #
def test_member_interactions_and_segments():
    p = MemberManagementPrism(_http(FakeTransport()))
    for _ in range(5):
        p.record_interaction("ch1", "u1", "comment", weight=3.0)
    p.record_interaction("ch1", "u2", "like", weight=1.0)
    m = p.get_member("ch1", "u1")
    assert m["score"] == 15.0
    seg = p.segment_members("ch1")
    assert any(x["user_id"] == "u1" for x in seg["active"])
    assert any(x["user_id"] == "u2" for x in seg["new"])


def test_member_patterns_and_top():
    p = MemberManagementPrism(_http(FakeTransport()))
    p.record_interaction("ch1", "u1", "comment", weight=5.0)
    p.record_interaction("ch1", "u2", "like", weight=2.0)
    pat = p.interaction_patterns("ch1")
    assert pat["member_count"] == 2
    assert pat["by_type"]["comment"] == 1
    top = p.top_members("ch1", limit=1)
    assert top[0]["user_id"] == "u1"


# --------------------------------------------------------------------------- #
# AnalyticsPrism
# --------------------------------------------------------------------------- #
def test_engagement_summary():
    p = AnalyticsPrism(_http(FakeTransport()))
    threads = [
        {"snippet": {"topLevelComment": {"snippet": {
            "textDisplay": "love it, amazing", "likeCount": 10}},
            "replies": {"comments": [{"id": "r1"}]}}},
        {"snippet": {"topLevelComment": {"snippet": {
            "textDisplay": "terrible and boring", "likeCount": 2}}}},
    ]
    s = p.engagement_summary(threads)
    assert s["thread_count"] == 2
    assert s["total_likes"] == 12
    assert s["total_replies"] == 1
    assert s["sentiment_counts"]["positive"] == 1
    assert s["sentiment_counts"]["negative"] == 1


def test_campaign_lifecycle():
    p = AnalyticsPrism(_http(FakeTransport()))
    camp = p.create_campaign("Q4 Growth", "ch1", goals={"subs": 1000})
    cid = camp["id"]
    p.record_campaign_metric(cid, "new_subs", 100)
    p.record_campaign_metric(cid, "new_subs", 300)
    report = p.campaign_report(cid)
    assert report["metrics"]["new_subs"]["sum"] == 400
    assert report["metrics"]["new_subs"]["avg"] == 200
    p.close_campaign(cid)
    assert p.persistence.get("campaign:" + cid)["status"] == "closed"


def test_analytics_report():
    p = AnalyticsPrism(_http(FakeTransport()))
    rep = p.report(threads=[], channel_id="ch1")
    assert rep["channel_id"] == "ch1"
    assert "engagement" in rep and "sentiment" in rep


# --------------------------------------------------------------------------- #
# Rate limiting + retry + quota
# --------------------------------------------------------------------------- #
def test_rate_limit_429_retry():
    t = FakeTransport([
        (429, {"Retry-After": "0"}, b'{"retry_after": 0}'),
        (200, {}, b'{"ok": true}'),
    ])
    h = _http(t)
    result = h.request("GET", "videos", params={"id": "v1"})
    assert result["ok"] is True
    assert len(t.calls) == 2


def test_rate_limited_after_max_retries():
    t = FakeTransport([(429, {"Retry-After": "0"}, b'{"retry_after":0}')] * 7)
    h = YouTubeHTTP("tok", transport=t, max_retries=3, sleep_fn=lambda s: None)
    try:
        h.request("GET", "videos")
        assert False, "expected RateLimitedError"
    except RateLimitedError:
        pass


def test_quota_accounting():
    rl = RateLimiter(daily_quota=150, sleep_fn=lambda s: None)
    h = YouTubeHTTP("tok", limiter=rl, transport=FakeTransport(),
                    sleep_fn=lambda s: None)
    # search costs 100 units
    h.request("GET", "search", params={"q": "x"})
    assert rl.quota_used == 100
    assert rl.quota_remaining() == 50
    # a second search (100) would exceed 150 -> RateLimitedError
    try:
        h.request("GET", "search", params={"q": "y"})
        assert False, "expected quota RateLimitedError"
    except RateLimitedError:
        pass


def test_error_mapping_404_403_400():
    h404 = _http(FakeTransport([(404, {}, b'{"error":{}}')]))
    try:
        h404.request("GET", "videos")
        assert False
    except NotFoundError:
        pass
    h403 = _http(FakeTransport([(403, {}, b'{"error":{}}')]))
    try:
        h403.request("GET", "videos")
        assert False
    except ForbiddenError:
        pass
    h400 = _http(FakeTransport([(400, {}, b'{"error":{}}')]))
    try:
        h400.request("GET", "videos")
        assert False
    except ValidationError:
        pass


def test_quota_exceeded_maps_to_rate_limited():
    body = b'{"error":{"errors":[{"reason":"quotaExceeded"}]}}'
    h = _http(FakeTransport([(403, {}, body)]))
    try:
        h.request("GET", "search")
        assert False
    except RateLimitedError:
        pass


def test_rate_limiter_bucket():
    rl = RateLimiter(sleep_fn=lambda s: None)
    rl.update_from_headers("GET videos", {"X-RateLimit-Limit": "5",
                                          "X-RateLimit-Remaining": "5"})
    for _ in range(5):
        rl.acquire("GET videos")
    b = rl._bucket("GET videos")
    assert b.tokens < 1.0


# --------------------------------------------------------------------------- #
# Event emission + persistence + Lux handler contract
# --------------------------------------------------------------------------- #
def test_event_emission():
    events = EventEmitter()
    seen = []
    events.on("CommentModeration.moderation_status_set",
              lambda **k: seen.append(k))
    p = CommentModerationPrism(_http(FakeTransport([(200, {}, b"{}")])),
                               events=events)
    p.hold_for_review("c1")
    assert seen and seen[0]["comment_id"] == "c1"


def test_persistence_backend():
    p = CommunityPostPrism(_http(FakeTransport()),
                           persistence=InMemoryPersistence())
    post = p.schedule_post("ch1", "hi", scheduled_for=1)
    assert p.persistence.get("community_post:" + post["id"]) is not None


def test_lux_handler_contract():
    p = CommunityPostPrism(_http(FakeTransport()))
    ok = p.handler("schedule_post",
                   {"channel_id": "ch1", "content": "hi", "scheduled_for": 1})
    assert ok["ok"] is True and ok["data"]["status"] == "scheduled"
    bad = p.handler("schedule_post", {"channel_id": "ch1", "content": "",
                                      "scheduled_for": 1})
    assert bad["ok"] is False and bad["error"]["error"] == "validation_error"
    unknown = p.handler("does_not_exist", {})
    assert unknown["ok"] is False


# --------------------------------------------------------------------------- #
# Spec-mandated classes (spec lines 293-303)
# --------------------------------------------------------------------------- #
def test_comment_management_list_and_moderation():
    from youtube_community_prisms import CommentManagementPrism
    t = FakeTransport([
        (200, {}, b'{"items":[{"id":"t1"},{"id":"t2"}]}'),  # list threads
        (200, {}, b"{}"),                                    # set status
    ])
    p = CommentManagementPrism(_http(t))
    listed = p.list_comment_threads(video_id="v1")
    assert listed["items"][0]["id"] == "t1"
    res = p.approve_comment("c1")
    assert res["moderationStatus"] == "published"
    # invalid status rejected
    try:
        p.set_moderation_status("c1", "bogus")
        assert False, "expected ValidationError"
    except Exception as e:
        assert "validation" in str(e).lower() or "status" in str(e).lower()


def test_comment_management_post_and_delete():
    from youtube_community_prisms import CommentManagementPrism
    t = FakeTransport([
        (200, {}, b'{"id":"newthread"}'),  # post comment
        (200, {}, b"{}"),                  # delete
    ])
    p = CommentManagementPrism(_http(t))
    posted = p.post_comment("v1", "Great video!")
    assert posted["id"] == "newthread"
    deleted = p.delete_comment("c1")
    assert deleted["deleted"] is True
    # empty text rejected
    try:
        p.post_comment("v1", "   ")
        assert False
    except Exception:
        pass


def test_response_generation_generate_and_post():
    from youtube_community_prisms import ResponseGenerationPrism
    t = FakeTransport([(200, {}, b'{"id":"r1"}')])
    p = ResponseGenerationPrism(_http(t), creator_name="TeamA")
    r = p.generate_reply("How do I set up the API key?")
    assert r["intent"] == "question"
    assert "question" in r["reply"].lower()
    # batch
    batch = p.generate_replies(["Love it!", "This is terrible"])
    assert len(batch) == 2
    # auto reply posts
    out = p.auto_reply("c1", "Thanks so much!")
    assert out["posted"]["id"] == "r1"
    assert "suggestion" in out


def test_sentiment_analysis_prism():
    from youtube_community_prisms import SentimentAnalysisPrism
    p = SentimentAnalysisPrism(_http(FakeTransport()))
    assert p.analyze_text("absolutely amazing and helpful")["label"] == "positive"
    assert p.analyze_text("terrible boring waste")["label"] == "negative"
    batch = p.analyze_batch(["good great", "bad awful", "the table"])
    assert batch["count"] == 3
    assert batch["counts"]["positive"] >= 1
    assert batch["counts"]["negative"] >= 1
    # thread analysis
    thread = {"snippet": {"topLevelComment": {"id": "c9", "snippet": {
        "textDisplay": "love this"}}}}
    r = p.analyze_thread(thread)
    assert r["comment_id"] == "c9"
    assert r["label"] == "positive"


def test_spam_moderation_prism():
    from youtube_community_prisms import SpamModerationPrism
    t = FakeTransport([
        (200, {}, b"{}"),  # hold
        (200, {}, b"{}"),  # approve
    ])
    p = SpamModerationPrism(_http(t), spam_threshold=0.5)
    assert p.is_spam("BUY NOW!!! click here https://spam.example.com make money")
    assert not p.is_spam("Great tutorial, thanks for explaining this clearly.")
    held = p.moderate("c1", "BUY NOW!!! click here https://spam.example.com make money")
    assert held["decision"] == "held"
    approved = p.moderate("c2", "Great tutorial, thanks")
    assert approved["decision"] == "approved"


def test_community_post_scheduler():
    from youtube_community_prisms import CommunityPostSchedulerPrism
    p = CommunityPostSchedulerPrism(_http(FakeTransport()))
    post = p.schedule_post("ch1", "Hello world", scheduled_for=1000.0)
    assert post["status"] == "scheduled"
    assert p.queue_depth("ch1") == 1
    # process due posts
    published = p.process_due_posts(now=2000.0)
    assert len(published) == 1
    assert published[0]["status"] == "published"
    assert p.queue_depth("ch1") == 0
    # cancel
    p2 = CommunityPostSchedulerPrism(_http(FakeTransport()))
    post2 = p2.schedule_post("ch1", "Later", scheduled_for=9999.0)
    cancelled = p2.cancel_post(post2["id"])
    assert cancelled["status"] == "cancelled"


def test_engagement_campaign_prism():
    from youtube_community_prisms import EngagementCampaignPrism
    p = EngagementCampaignPrism(_http(FakeTransport()))
    camp = p.create_campaign("Spring Launch", "ch1", goals={"signups": 100})
    assert camp["status"] == "active"
    p.record_metric(camp["id"], "signups", 10)
    p.record_metric(camp["id"], "signups", 20)
    report = p.campaign_report(camp["id"])
    assert report["metrics"]["signups"]["count"] == 2
    assert report["metrics"]["signups"]["sum"] == 30
    assert report["metrics"]["signups"]["avg"] == 15
    closed = p.close_campaign(camp["id"])
    assert closed["status"] == "closed"
    assert len(p.list_campaigns(channel_id="ch1")) == 1


def test_comment_threads_lens():
    from youtube_community_prisms import CommentThreadsLens
    t = FakeTransport([
        (200, {}, b'{"items":[{"id":"t1","snippet":{"videoId":"v1",'
                    b'"topLevelComment":{"id":"c1","snippet":{'
                    b'"authorDisplayName":"alice","textDisplay":"nice",'
                    b'"likeCount":5}}}}]}'),
    ])
    lens = CommentThreadsLens(_http(t))
    rows = lens.get(video_id="v1")
    assert len(rows) == 1
    assert rows[0]["comment_id"] == "c1"
    assert rows[0]["author"] == "alice"
    assert rows[0]["like_count"] == 5


def test_community_management_beam_triage():
    from youtube_community_prisms import CommunityManagementBeam
    # one clean comment, one spam comment
    t = FakeTransport([
        (200, {}, b'{"items":['
                    b'{"id":"t1","snippet":{"videoId":"v1","topLevelComment":'
                    b'{"id":"c1","snippet":{"textDisplay":"great video love it"}}}},'
                    b'{"id":"t2","snippet":{"videoId":"v1","topLevelComment":'
                    b'{"id":"c2","snippet":{"textDisplay":"BUY NOW!!! '
                    b'click here https://spam.example.com make money"}}}}]}'),
        (200, {}, b"{}"),  # approve c1
        (200, {}, b"{}"),  # hold c2
    ])
    beam = CommunityManagementBeam(_http(t))
    report = beam.triage_threads(video_id="v1")
    assert report["total"] == 2
    assert report["counts"]["approved"] == 1
    assert report["counts"]["held"] == 1
    assert report["counts"]["spam"] == 1


def test_beam_handler_dispatch():
    from youtube_community_prisms import CommunityManagementBeam
    beam = CommunityManagementBeam(_http(FakeTransport()))
    ok = beam.handler("triage_threads", {"video_id": "v1"})
    assert ok["ok"] is True
    bad = beam.handler("does_not_exist", {})
    assert bad["ok"] is False


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
    sys.exit(_run_all())