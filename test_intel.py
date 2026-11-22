"""
Unit tests for youtube_intel — lux issue #69 acceptance criteria.

Run:  python3 -m pytest test_intel.py -v
  or: python3 test_intel.py        (stdlib-only fallback runner)

Tests use an injected fake transport so NO network calls are made. Covers:
  * core: quota limiter, rate limiter, retry/backoff, 404/403/quota error
    mapping, event emission, persistence (memory + JSON file).
  * analytics: video fetch/batch, channel uploads, summarize, engagement
    analysis, view velocity, ISO-8601 duration parsing.
  * models: linear regression (OLS + ridge), logistic regression, posting-time
    optimizer, performance predictor.
  * optimizer: title/thumbnail/tag/description optimization, recommendation
    engine (TF-IDF), trending topic analysis.
  * integration: end-to-end content optimization workflow.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from youtube_intel import (  # noqa: E402
    AnalyticsEngine,
    DescriptionGenerator,
    EventEmitter,
    ForbiddenError,
    InMemoryPersistence,
    JsonFilePersistence,
    LinearRegression,
    LogisticRegression,
    NotFoundError,
    PerformancePredictor,
    PostingTimeOptimizer,
    QuotaExceededError,
    QuotaLimiter,
    RateLimitedError,
    RateLimiter,
    RecommendationEngine,
    ServerError,
    TagOptimizer,
    ThumbnailOptimizer,
    TitleOptimizer,
    TrendingTopicAnalyzer,
    VideoMetrics,
    YouTubeAPIError,
    YouTubeClient,
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


def _client(transport, api_key="test-key", quota=None, max_retries=5):
    return YouTubeClient(api_key, transport=transport, quota=quota,
                         max_retries=max_retries, sleep_fn=lambda s: None)


def _video_item(vid, title, views, likes, comments, published="2026-01-01T12:00:00Z",
                duration="PT10M30S"):
    return {
        "id": vid,
        "snippet": {"title": title, "publishedAt": published,
                    "tags": ["python", "coding"]},
        "statistics": {"viewCount": str(views), "likeCount": str(likes),
                       "commentCount": str(comments)},
        "contentDetails": {"duration": duration},
    }


# =========================================================================== #
# CORE
# =========================================================================== #
def test_quota_limiter_charge_and_remaining():
    q = QuotaLimiter(daily_limit=100)
    assert q.remaining() == 100
    rem = q.charge(30)
    assert rem == 70
    assert q.used() == 30
    assert q.remaining() == 70


def test_quota_limiter_exceeded():
    q = QuotaLimiter(daily_limit=50)
    q.charge(50)
    try:
        q.charge(1)
        assert False, "expected QuotaExceededError"
    except QuotaExceededError:
        pass


def test_quota_limiter_negative_units():
    q = QuotaLimiter(daily_limit=50)
    try:
        q.charge(-1)
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_quota_limiter_daily_reset():
    fake_now = [1_000_000.0]  # day 11
    q = QuotaLimiter(daily_limit=100, clock=lambda: fake_now[0])
    q.charge(100)
    assert q.remaining() == 0
    fake_now[0] += 86400  # next day
    assert q.remaining() == 100
    assert q.used() == 0


def test_quota_charged_on_request():
    q = QuotaLimiter(daily_limit=1000)
    t = FakeTransport([(200, {}, b'{"items": []}')])
    c = _client(t, quota=q)
    c.request("GET", "videos.list", params={"id": "x"})
    assert q.used() == 1  # videos.list cost = 1


def test_search_costs_100_units():
    q = QuotaLimiter(daily_limit=1000)
    t = FakeTransport([(200, {}, b'{"items": []}')])
    c = _client(t, quota=q)
    c.request("GET", "search.list", params={"q": "x"})
    assert q.used() == 100


def test_rate_limiter_bucket():
    rl = RateLimiter(capacity=5, refill=1000)
    for _ in range(5):
        rl.acquire("GET /x")
    b = rl._bucket("GET /x")
    assert b.tokens < 1.0


def test_rate_limiter_pause():
    rl = RateLimiter(capacity=5, refill=1000)
    rl.pause("GET /x", 0.0)
    b = rl._bucket("GET /x")
    assert b.tokens == 0.0


def test_retry_on_500_then_success():
    t = FakeTransport([
        (500, {}, b'{"error": {"message": "boom"}}'),
        (200, {}, b'{"ok": true}'),
    ])
    c = _client(t)
    result = c.request("GET", "videos.list")
    assert result["ok"] is True
    assert len(t.calls) == 2


def test_server_error_after_max_retries():
    t = FakeTransport([(503, {}, b"{}")] * 10)
    c = _client(t, max_retries=2)
    try:
        c.request("GET", "videos.list")
        assert False, "expected ServerError"
    except ServerError:
        pass


def test_rate_limit_429_retry():
    t = FakeTransport([
        (429, {"Retry-After": "0"}, b'{"retry_after": 0}'),
        (200, {}, b'{"id": "ok"}'),
    ])
    c = _client(t)
    result = c.request("GET", "videos.list")
    assert result["id"] == "ok"
    assert len(t.calls) == 2


def test_rate_limited_after_max_retries():
    t = FakeTransport([(429, {"Retry-After": "0"}, b'{"retry_after":0}')] * 7)
    c = _client(t, max_retries=3)
    try:
        c.request("GET", "videos.list")
        assert False, "expected RateLimitedError"
    except RateLimitedError:
        pass


def test_error_mapping_404():
    c = _client(FakeTransport([(404, {}, b'{"error": {"message": "nope"}}')]))
    try:
        c.request("GET", "videos.list")
        assert False
    except NotFoundError:
        pass


def test_error_mapping_403_forbidden():
    c = _client(FakeTransport([(403, {}, b'{"error": {"message": "denied"}}')]))
    try:
        c.request("GET", "videos.list")
        assert False
    except ForbiddenError:
        pass


def test_error_mapping_403_quota():
    body = b'{"error": {"errors": [{"reason": "quotaExceeded"}]}}'
    c = _client(FakeTransport([(403, {}, body)]))
    try:
        c.request("GET", "videos.list")
        assert False
    except QuotaExceededError:
        pass


def test_generic_400_error():
    c = _client(FakeTransport([(400, {}, b'{"error": {"message": "bad"}}')]))
    try:
        c.request("GET", "videos.list")
        assert False
    except YouTubeAPIError as e:
        assert e.status == 400


def test_api_key_in_url():
    t = FakeTransport([(200, {}, b"{}")])
    c = _client(t, api_key="SECRET123")
    c.request("GET", "videos.list", params={"id": "x"})
    assert "key=SECRET123" in t.calls[0][1]


def test_event_emitter_on_off_emit():
    ev = EventEmitter()
    seen = []
    h = lambda **k: seen.append(k)  # noqa: E731
    ev.on("evt", h)
    ev.emit("evt", a=1)
    assert seen == [{"a": 1}]
    ev.off("evt", h)
    ev.emit("evt", a=2)
    assert len(seen) == 1


def test_event_emitter_isolates_failures():
    ev = EventEmitter()
    good = []
    ev.on("evt", lambda **k: (_ for _ in ()).throw(RuntimeError("boom")))
    ev.on("evt", lambda **k: good.append(1))
    ev.emit("evt")  # must not raise
    assert good == [1]


def test_inmemory_persistence():
    p = InMemoryPersistence()
    p.set("k", {"v": 1})
    assert p.get("k") == {"v": 1}
    assert p.get("missing", "d") == "d"
    p.delete("k")
    assert p.get("k") is None
    assert "k" not in p.all()


def test_json_file_persistence(tmp_path=None):
    import tempfile
    d = tempfile.mkdtemp()
    path = os.path.join(d, "state.json")
    p = JsonFilePersistence(path)
    p.set("key", [1, 2, 3])
    # reload from disk
    p2 = JsonFilePersistence(path)
    assert p2.get("key") == [1, 2, 3]
    p2.delete("key")
    p3 = JsonFilePersistence(path)
    assert p3.get("key") is None


# =========================================================================== #
# ANALYTICS
# =========================================================================== #
def test_video_metrics_from_item():
    m = VideoMetrics.from_item(_video_item("v1", "Title", 1000, 50, 25))
    assert m.video_id == "v1"
    assert m.views == 1000
    assert m.likes == 50
    assert m.comments == 25
    assert abs(m.engagement_rate - 0.075) < 1e-9
    assert abs(m.like_ratio - 0.05) < 1e-9
    assert m.duration_seconds == 630  # PT10M30S


def test_video_metrics_zero_views():
    m = VideoMetrics("v", "t", 0, 0, 0)
    assert m.engagement_rate == 0.0
    assert m.like_ratio == 0.0


def test_iso8601_duration_parsing():
    from youtube_intel.analytics import _parse_iso8601_duration
    assert _parse_iso8601_duration("PT1H2M3S") == 3723
    assert _parse_iso8601_duration("PT45S") == 45
    assert _parse_iso8601_duration("") == 0.0
    assert _parse_iso8601_duration("P1DT2H") == 93600


def test_fetch_video():
    t = FakeTransport([(200, {}, _items(_video_item("v1", "T", 100, 10, 5)))])
    eng = AnalyticsEngine(_client(t))
    m = eng.fetch_video("v1")
    assert m.video_id == "v1"
    assert m.views == 100


def test_fetch_video_not_found():
    t = FakeTransport([(200, {}, b'{"items": []}')])
    eng = AnalyticsEngine(_client(t))
    try:
        eng.fetch_video("missing")
        assert False
    except NotFoundError:
        pass


def test_fetch_videos_batch():
    items = [_video_item(f"v{i}", f"T{i}", 100 * i, 10, 5) for i in range(3)]
    t = FakeTransport([(200, {}, _items(*items))])
    eng = AnalyticsEngine(_client(t))
    ms = eng.fetch_videos(["v0", "v1", "v2"])
    assert len(ms) == 3


def test_fetch_channel_videos():
    ch = {"items": [{"contentDetails":
                     {"relatedPlaylists": {"uploads": "UU123"}}}]}
    pl = {"items": [{"contentDetails": {"videoId": "a"}},
                    {"contentDetails": {"videoId": "b"}}]}
    vids = [_video_item("a", "A", 100, 1, 1), _video_item("b", "B", 200, 2, 2)]
    t = FakeTransport([
        (200, {}, _json(ch)),
        (200, {}, _json(pl)),
        (200, {}, _items(*vids)),
    ])
    eng = AnalyticsEngine(_client(t))
    ms = eng.fetch_channel_videos("UC123")
    assert len(ms) == 2


def test_fetch_channel_not_found():
    t = FakeTransport([(200, {}, b'{"items": []}')])
    eng = AnalyticsEngine(_client(t))
    try:
        eng.fetch_channel_videos("nope")
        assert False
    except NotFoundError:
        pass


def test_summarize():
    ms = [VideoMetrics("a", "A", 100, 10, 5),
          VideoMetrics("b", "B", 300, 20, 10),
          VideoMetrics("c", "C", 200, 15, 5)]
    eng = AnalyticsEngine(_client(FakeTransport()))
    s = eng.summarize(ms)
    assert s["count"] == 3
    assert s["total_views"] == 600
    assert abs(s["mean_views"] - 200.0) < 1e-9
    assert s["median_views"] == 200
    assert s["top_video"]["video_id"] == "b"
    assert s["bottom_video"]["video_id"] == "a"


def test_summarize_empty():
    eng = AnalyticsEngine(_client(FakeTransport()))
    assert eng.summarize([]) == {"count": 0}


def test_engagement_analysis():
    ms = [VideoMetrics("a", "A", 1000, 100, 50),   # 15%
          VideoMetrics("b", "B", 1000, 10, 5)]      # 1.5%
    eng = AnalyticsEngine(_client(FakeTransport()))
    a = eng.engagement_analysis(ms)
    assert a["count"] == 2
    assert a["most_engaging"]["video_id"] == "a"
    assert a["least_engaging"]["video_id"] == "b"
    assert a["above_average_count"] == 1
    assert 0.0 <= a["engagement_score"] <= 100.0


def test_engagement_analysis_empty():
    eng = AnalyticsEngine(_client(FakeTransport()))
    assert eng.engagement_analysis([]) == {"count": 0}


def test_view_velocity():
    ms = [VideoMetrics("a", "A", 1000, 10, 5, published_at="2026-01-01T00:00:00Z")]
    eng = AnalyticsEngine(_client(FakeTransport()))
    import calendar
    now = calendar.timegm((2026, 1, 11, 0, 0, 0))  # 10 days later
    vel = eng.view_velocity(ms, now_epoch=now)
    assert vel[0]["video_id"] == "a"
    assert abs(vel[0]["age_days"] - 10.0) < 1e-6
    assert abs(vel[0]["views_per_day"] - 100.0) < 1e-6


def test_analytics_emits_event():
    ev = EventEmitter()
    seen = []
    ev.on("Analytics.video_fetched", lambda **k: seen.append(k))
    t = FakeTransport([(200, {}, _items(_video_item("v1", "T", 1, 1, 1)))])
    eng = AnalyticsEngine(_client(t), events=ev)
    eng.fetch_video("v1")
    assert seen and seen[0]["video_id"] == "v1"


# =========================================================================== #
# MODELS
# =========================================================================== #
def test_linear_regression_fit_predict():
    # y = 2x + 1 (single feature)
    x = [[0.0], [1.0], [2.0], [3.0]]
    y = [1.0, 3.0, 5.0, 7.0]
    lr = LinearRegression().fit(x, y)
    pred = lr.predict_one([10.0])
    assert abs(pred - 21.0) < 1e-6
    assert lr.score(x, y) > 0.999


def test_linear_regression_multifeature():
    x = [[1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [2.0, 1.0]]
    y = [1.0, 2.0, 3.0, 4.0]
    lr = LinearRegression(l2=0.01).fit(x, y)
    assert len(lr.predict(x)) == 4


def test_linear_regression_no_intercept():
    x = [[1.0], [2.0], [3.0]]
    y = [2.0, 4.0, 6.0]
    lr = LinearRegression(fit_intercept=False).fit(x, y)
    assert abs(lr.predict_one([5.0]) - 10.0) < 1e-6


def test_linear_regression_errors():
    lr = LinearRegression()
    try:
        lr.fit([], [])
        assert False
    except ValueError:
        pass
    try:
        lr.predict([[1.0]])
        assert False
    except ValueError:
        pass
    try:
        lr.fit([[1.0]], [1.0, 2.0])
        assert False
    except ValueError:
        pass


def test_linear_regression_residual_std():
    x = [[0.0], [1.0], [2.0]]
    y = [1.0, 2.0, 3.0]
    lr = LinearRegression().fit(x, y)
    assert lr.residual_std(x, y) < 1e-6


def test_logistic_regression():
    x = [[0.0], [0.1], [0.2], [1.0], [1.1], [1.2]]
    y = [0, 0, 0, 1, 1, 1]
    clf = LogisticRegression(learning_rate=0.5, epochs=800).fit(x, y)
    assert clf.predict([[0.05]])[0] == 0
    assert clf.predict([[1.15]])[0] == 1
    assert clf.score(x, y) == 1.0
    proba = clf.predict_proba([[0.05]])
    assert 0.0 <= proba[0] <= 1.0


def test_logistic_regression_errors():
    clf = LogisticRegression()
    try:
        clf.fit([], [])
        assert False
    except ValueError:
        pass
    try:
        clf.predict([[1.0]])
        assert False
    except ValueError:
        pass


def test_posting_time_optimizer():
    opt = PostingTimeOptimizer(smoothing=1.0)
    # Monday 9am is consistently great; Sunday 3am poor
    for _ in range(10):
        opt.add(0, 9, 100.0)
    for _ in range(10):
        opt.add(6, 3, 5.0)
    best = opt.best_slot()
    assert best["day"] == 0
    assert best["hour"] == 9
    top = opt.best_times(top_k=2)
    assert top[0]["day_name"] == "Mon"


def test_posting_time_optimizer_fit():
    obs = [(0, 9, 100.0), (0, 9, 110.0), (6, 3, 5.0)]
    opt = PostingTimeOptimizer().fit(obs)
    assert opt.best_slot()["day"] == 0


def test_posting_time_optimizer_empty():
    opt = PostingTimeOptimizer()
    assert opt.best_times() == []
    assert opt.best_slot() is None


def test_performance_predictor():
    vids = []
    for i in range(20):
        vids.append({
            "title": "Python tutorial " + "x" * i,
            "tags": ["python"] * (i % 5),
            "description": "learn " * i,
            "has_thumbnail": True,
            "published_hour": 9,
            "published_day": 0,
            "views": 1000 + i * 100,
        })
    p = PerformancePredictor(l2=0.1).fit(vids)
    pred = p.predict(vids[10])
    assert "predicted_views" in pred
    assert pred["lower"] <= pred["predicted_views"] <= pred["upper"]
    imp = p.feature_importance()
    assert set(imp) == set(PerformancePredictor.FEATURE_NAMES)


def test_performance_predictor_not_fitted():
    p = PerformancePredictor()
    try:
        p.predict({"title": "x"})
        assert False
    except ValueError:
        pass


def test_performance_predictor_featurize_snippet():
    v = {"snippet": {"title": "Hello", "tags": ["a", "b"],
                     "description": "desc"}, "published_hour": 8}
    feats = PerformancePredictor.featurize(v)
    assert feats[0] == 5.0  # len("Hello")
    assert feats[1] == 2.0  # 2 tags


# =========================================================================== #
# OPTIMIZER
# =========================================================================== #
def test_title_optimizer_score():
    opt = TitleOptimizer()
    good = opt.score("How to Master Python: 7 Proven Tips for Beginners",
                     keyword="python")
    bad = opt.score("x", keyword="python")
    assert good["score"] > bad["score"]
    assert "length" in good["components"]


def test_title_optimizer_suggest():
    opt = TitleOptimizer()
    sugg = opt.suggest("Learn Python Fast", keyword="python")
    assert len(sugg) >= 1
    assert all("score" in s for s in sugg)
    # suggestions should be sorted descending
    scores = [s["score"] for s in sugg]
    assert scores == sorted(scores, reverse=True)


def test_title_optimizer_empty():
    opt = TitleOptimizer()
    s = opt.score("")
    assert s["score"] == 0.0 or s["length"] == 0


def test_thumbnail_optimizer():
    opt = ThumbnailOptimizer()
    good = opt.score({"has_face": True, "has_text": True,
                      "text_word_count": 3, "contrast": 0.8,
                      "brightness": 0.5, "has_brand": True})
    bad = opt.score({"has_face": False, "has_text": False,
                     "text_word_count": 0, "contrast": 0.1,
                     "brightness": 0.0})
    assert good["score"] > bad["score"]
    sugg = opt.suggest({"has_face": False, "has_text": False,
                        "text_word_count": 0, "contrast": 0.1})
    assert len(sugg) >= 2
    assert sugg[0]["score"] >= sugg[-1]["score"]


def test_tag_optimizer():
    opt = TagOptimizer(max_tags=5)
    result = opt.optimize("python machine learning tutorial for beginners",
                          keyword="python")
    assert result["count"] <= 5
    assert result["char_count"] <= TagOptimizer.MAX_TOTAL_CHARS
    assert "python" in result["tags"]
    assert isinstance(result["tag_string"], str)


def test_tag_optimizer_extract():
    opt = TagOptimizer()
    tags = opt.extract("python python coding tutorial", keyword="python")
    assert tags[0] == "python"


def test_description_generator():
    gen = DescriptionGenerator(channel_name="CodeHub",
                               call_to_action="Subscribe now!")
    d = gen.generate("Python Tips", tags=["python", "coding"],
                     transcript="we discuss python and coding best practices")
    assert "Python Tips" in d["description"]
    assert "Subscribe now!" in d["description"]
    assert "Tags:" in d["description"]
    assert len(d["keywords"]) > 0


def test_description_generator_long_transcript():
    gen = DescriptionGenerator()
    d = gen.generate("T", transcript="word " * 200)
    assert d["char_count"] == len(d["description"])


def test_recommendation_engine():
    items = [
        {"video_id": "1", "title": "python machine learning tutorial",
         "tags": ["python", "ml"]},
        {"video_id": "2", "title": "python data science guide",
         "tags": ["python", "data"]},
        {"video_id": "3", "title": "cooking pasta recipe",
         "tags": ["cooking", "food"]},
    ]
    rec = RecommendationEngine().fit(items)
    res = rec.recommend("1", top_k=2)
    assert len(res) == 2
    # most similar to python video should be the other python video
    assert res[0]["video_id"] == "2"
    assert res[0]["similarity"] > res[1]["similarity"]


def test_recommendation_engine_unknown():
    rec = RecommendationEngine().fit([{"video_id": "1", "title": "x"}])
    assert rec.recommend("unknown") == []


def test_recommendation_engine_not_fitted():
    rec = RecommendationEngine()
    try:
        rec.recommend("1")
        assert False
    except ValueError:
        pass


def test_trending_topic_analyzer():
    import time
    now = time.time()
    corpus = [
        ("python ai machine learning", now),
        ("python tutorial", now),
        ("python ai deep learning", now - 86400),
        ("cooking recipe food", now),
    ]
    ta = TrendingTopicAnalyzer()
    topics = ta.analyze(corpus, top_k=5)
    assert topics[0]["topic"] == "python"
    assert topics[0]["frequency"] >= 3


def test_trending_topic_plain_strings():
    ta = TrendingTopicAnalyzer()
    topics = ta.analyze(["python rocks", "python is great"], top_k=3)
    assert any(t["topic"] == "python" for t in topics)


def test_trending_hashtags():
    ta = TrendingTopicAnalyzer()
    tags = ta.hashtags(["#Python rocks", "use #AI and #python"], top_k=3)
    assert "#python" in tags
    assert "#ai" in tags


# =========================================================================== #
# INTEGRATION — end-to-end content optimization workflow
# =========================================================================== #
def test_integration_optimization_workflow():
    """Showcase the full content optimization workflow from issue #69."""
    # 1. Collect analytics for a channel's recent videos.
    ch = {"items": [{"contentDetails":
                     {"relatedPlaylists": {"uploads": "UU"}}}]}
    pl = {"items": [{"contentDetails": {"videoId": "a"}},
                    {"contentDetails": {"videoId": "b"}},
                    {"contentDetails": {"videoId": "c"}}]}
    vids = [
        _video_item("a", "Intro to Python", 5000, 300, 100),
        _video_item("b", "Advanced Python Tips", 12000, 900, 250),
        _video_item("c", "Python Crash Course", 8000, 500, 150),
    ]
    t = FakeTransport([
        (200, {}, _json(ch)),
        (200, {}, _json(pl)),
        (200, {}, _json({"items": vids})),
    ])
    eng = AnalyticsEngine(_client(t))
    metrics = eng.fetch_channel_videos("UC")

    # 2. Process engagement.
    summary = eng.summarize(metrics)
    engagement = eng.engagement_analysis(metrics)
    assert summary["count"] == 3
    assert engagement["most_engaging"]["video_id"] == "b"

    # 3. Train a performance predictor on the collected data.
    train = [{
        "title": m.title, "tags": ["python"], "description": "desc",
        "has_thumbnail": True, "published_hour": 9, "published_day": 0,
        "views": m.views,
    } for m in metrics]
    predictor = PerformancePredictor(l2=0.1).fit(train)
    pred = predictor.predict({"title": "New Python Video", "tags": ["python"],
                              "description": "x", "has_thumbnail": True,
                              "published_hour": 9, "published_day": 0})
    assert pred["predicted_views"] >= 0

    # 4. Optimize metadata for the next upload.
    title_opt = TitleOptimizer()
    title_sugg = title_opt.suggest("Python Video", keyword="python")
    tag_opt = TagOptimizer()
    tags = tag_opt.optimize("python tutorial for data science",
                            keyword="python")
    desc_gen = DescriptionGenerator(channel_name="CodeHub")
    desc = desc_gen.generate(title_sugg[0]["title"], tags=tags["tags"])
    assert desc["description"]

    # 5. Recommend related content.
    corpus = [{"video_id": m.video_id, "title": m.title,
               "tags": ["python"]} for m in metrics]
    rec = RecommendationEngine().fit(corpus)
    related = rec.recommend("a", top_k=2)
    assert len(related) == 2

    # 6. Posting-time optimization.
    opt = PostingTimeOptimizer()
    for _ in range(5):
        opt.add(1, 14, 200.0)  # Tuesday 2pm strong
    assert opt.best_slot()["day"] == 1

    # 7. Trending topics.
    ta = TrendingTopicAnalyzer()
    topics = ta.analyze([m.title for m in metrics], top_k=3)
    assert len(topics) >= 1


def _json(obj):
    import json as _j
    return _j.dumps(obj).encode()


def _items(*videos):
    """Wrap video items in the YouTube API's ``{"items": [...]}`` envelope."""
    return _json({"items": list(videos)})


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
            import traceback
            print(f"  FAIL {t.__name__}: {e}")
            traceback.print_exc()
            failed += 1
    print(f"\n{passed} passed, {failed} failed, {len(tests)} total")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    try:
        import pytest  # noqa: F401
        sys.exit(_run_all())
    except ImportError:
        sys.exit(_run_all())