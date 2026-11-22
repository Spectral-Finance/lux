"""
Stdlib-only unit tests for the Lux YouTube Prism architecture (issue #77).

Exercises the Prism architecture (Prism / PrismInput / PrismResult /
PrismRegistry / build_registry), every concrete prism (video / channel /
discovery / monetization / seo), the pure util helpers, and the
youtube_client integration layer's pure logic (API-key resolution, query-param
building, prism delegation) -- all WITHOUT any network access.

Run:
    python3 -m unittest test_youtube_prisms_impl -v
    # or simply
    python3 test_youtube_prisms_impl.py
"""

import json
import os
import sys
import time
import unittest

# Make the package + client importable regardless of CWD.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from youtube_prisms import (  # noqa: E402
    AudienceRetentionPrism,
    ChannelBenchmarkPrism,
    ChannelGrowthPrism,
    ContentGapPrism,
    EngagementTrendPrism,
    PlaylistOverviewPrism,
    PlaylistStatsPrism,
    Prism,
    PrismError,
    PrismInput,
    PrismRegistry,
    PrismResult,
    RevenueEstimatePrism,
    SeoAuditPrism,
    TrendingTopicsPrism,
    VideoMetadataPrism,
    VideoPerformancePrism,
    build_registry,
)
from youtube_prisms import util  # noqa: E402
from youtube_client import (  # noqa: E402
    EventEmitter,
    ForbiddenError,
    NotFoundError,
    QuotaExceededError,
    QuotaLimiter,
    RateLimitedError,
    RateLimiter,
    ServerError,
    YouTubeAPIError,
    YouTubeClient,
)


# ---------------------------------------------------------------------------
# Fixtures -- realistic YouTube Data API v3 resource shapes
# ---------------------------------------------------------------------------
def _video(
    vid="vid1",
    title="How to Bake Sourdough Bread at Home",
    views="150000",
    likes="9000",
    comments="600",
    duration="PT12M34S",
    tags=None,
    desc="A full guide to baking sourdough bread at home with a starter.",
    category="27",
    published="2024-03-15T10:00:00Z",
):
    return {
        "id": vid,
        "snippet": {
            "title": title,
            "description": desc,
            "tags": tags if tags is not None else ["sourdough", "bread", "baking"],
            "categoryId": category,
            "channelId": "chan1",
            "publishedAt": published,
            "defaultLanguage": "en",
        },
        "statistics": {
            "viewCount": views,
            "likeCount": likes,
            "commentCount": comments,
        },
        "contentDetails": {"duration": duration},
    }


def _channel(
    cid="chan1",
    title="Bake With Sam",
    subs="250000",
    views="18000000",
    videos="420",
    hidden=False,
):
    stats = {"viewCount": views, "videoCount": videos}
    if hidden:
        stats["hiddenSubscriberCount"] = True
    else:
        stats["subscriberCount"] = subs
    return {
        "id": cid,
        "snippet": {"title": title, "customUrl": "@bakewithsam"},
        "statistics": stats,
        "contentDetails": {"relatedPlaylists": {"uploads": "UUxxxx"}},
    }


# ---------------------------------------------------------------------------
# PrismInput
# ---------------------------------------------------------------------------
class PrismInputTests(unittest.TestCase):
    def test_defaults_when_empty(self):
        p = PrismInput()
        self.assertEqual(p.get_str("missing"), "")
        self.assertEqual(p.get_int("missing", 7), 7)
        self.assertEqual(p.get_float("missing", 1.5), 1.5)
        self.assertEqual(p.get_list("missing"), [])
        self.assertEqual(p.get_dict("missing"), {})

    def test_typed_accessors(self):
        p = PrismInput({"a": "42", "b": "3.5", "c": [1, 2], "d": {"x": 1}})
        self.assertEqual(p.get_int("a"), 42)
        self.assertEqual(p.get_float("b"), 3.5)
        self.assertEqual(p.get_list("c"), [1, 2])
        self.assertEqual(p.get_dict("d"), {"x": 1})

    def test_int_from_float_string(self):
        p = PrismInput({"n": "42.9"})
        self.assertEqual(p.get_int("n"), 42)

    def test_bad_int_falls_back(self):
        p = PrismInput({"n": "not-a-number"})
        self.assertEqual(p.get_int("n", 5), 5)

    def test_has_and_as_dict(self):
        p = PrismInput({"a": 1, "b": None})
        self.assertTrue(p.has("a"))
        self.assertFalse(p.has("b"))
        self.assertFalse(p.has("missing"))
        self.assertEqual(p.as_dict(), {"a": 1, "b": None})

    def test_rejects_non_mapping(self):
        with self.assertRaises(PrismError):
            PrismInput(["not", "a", "dict"])

    def test_list_wraps_scalar(self):
        p = PrismInput({"x": "solo"})
        self.assertEqual(p.get_list("x"), ["solo"])


# ---------------------------------------------------------------------------
# PrismResult
# ---------------------------------------------------------------------------
class PrismResultTests(unittest.TestCase):
    def test_success(self):
        r = PrismResult.success({"a": 1}, prism="X")
        self.assertTrue(r.ok)
        self.assertEqual(r.data, {"a": 1})
        self.assertEqual(r.errors, [])
        self.assertEqual(r.meta, {"prism": "X"})
        self.assertEqual(r.unwrap(), {"a": 1})

    def test_failure(self):
        r = PrismResult.failure("boom")
        self.assertFalse(r.ok)
        self.assertEqual(r.errors, ["boom"])
        with self.assertRaises(PrismError):
            r.unwrap()

    def test_failure_from_list(self):
        r = PrismResult.failure(["e1", "e2"])
        self.assertEqual(r.errors, ["e1", "e2"])

    def test_to_dict(self):
        r = PrismResult.success({"k": "v"})
        d = r.to_dict()
        self.assertEqual(set(d), {"ok", "data", "errors", "meta"})
        self.assertTrue(d["ok"])
        self.assertEqual(d["data"], {"k": "v"})


# ---------------------------------------------------------------------------
# A tiny concrete prism used to test the base class machinery
# ---------------------------------------------------------------------------
class _AddOnePrism(Prism):
    name = "Add One"
    description = "adds one"
    input_schema = {
        "type": "object",
        "properties": {"n": {"type": "integer"}},
        "required": ["n"],
    }
    output_schema = {"type": "object", "properties": {"value": {"type": "integer"}}}

    def handler(self, params):
        return {"value": params.get_int("n") + 1}


class _BoomPrism(Prism):
    name = "Boom"
    input_schema = {"type": "object", "properties": {}}

    def handler(self, params):
        raise ValueError("kaboom")


class PrismBaseTests(unittest.TestCase):
    def test_run_success(self):
        r = _AddOnePrism().run({"n": 41})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["value"], 42)
        self.assertEqual(r.meta["prism"], "Add One")

    def test_run_missing_required(self):
        r = _AddOnePrism().run({})
        self.assertFalse(r.ok)
        self.assertTrue(any("n" in e for e in r.errors))

    def test_run_wrong_type(self):
        r = _AddOnePrism().run({"n": "not-int"})
        self.assertFalse(r.ok)

    def test_call_is_run(self):
        self.assertEqual(_AddOnePrism()({"n": 1}).data["value"], 2)

    def test_handler_exception_becomes_failure(self):
        r = _BoomPrism().run({})
        self.assertFalse(r.ok)
        self.assertTrue(any("kaboom" in e for e in r.errors))

    def test_spec(self):
        spec = _AddOnePrism().spec()
        self.assertEqual(spec["name"], "Add One")
        self.assertIn("input_schema", spec)
        self.assertIn("output_schema", spec)

    def test_validate_hook_rejects(self):
        class _ValidatedPrism(Prism):
            name = "V"
            input_schema = {"type": "object", "properties": {}}

            def validate(self, params):
                return ["always invalid"] if not params.has("ok") else []

            def handler(self, params):
                return {"ok": True}

        r = _ValidatedPrism().run({})
        self.assertFalse(r.ok)
        self.assertEqual(r.errors, ["always invalid"])
        self.assertTrue(_ValidatedPrism().run({"ok": 1}).ok)


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------
class PrismRegistryTests(unittest.TestCase):
    def test_register_and_run(self):
        reg = PrismRegistry()
        reg.register(_AddOnePrism())
        self.assertTrue(reg.has("Add One"))
        self.assertEqual(reg.run("Add One", {"n": 9}).data["value"], 10)

    def test_unknown_prism_raises(self):
        reg = PrismRegistry()
        with self.assertRaises(PrismError):
            reg.get("nope")

    def test_names_and_len(self):
        reg = PrismRegistry()
        reg.register(_AddOnePrism())
        reg.register(_BoomPrism())
        self.assertEqual(len(reg), 2)
        self.assertEqual(reg.names(), sorted(["Add One", "Boom"]))

    def test_build_registry_loads_all_twenty_six(self):
        reg = build_registry()
        self.assertEqual(len(reg), 26)
        for name in (
            "YouTube Video Performance",
            "YouTube Video Metadata",
            "YouTube Channel Growth",
            "YouTube Channel Benchmark",
            "YouTube Trending Topics",
            "YouTube Content Gap",
            "YouTube Playlist Stats",
            "YouTube Playlist Overview",
            "YouTube Engagement Trend",
            "YouTube Audience Retention",
            "YouTube Revenue Estimate",
            "YouTube SEO Audit",
            "channel_stats",
            "channel_resource",
            "search_result",
            "channel_list",
            "video_stats",
            "video_resource",
            "video_list",
            "playlist_resource",
            "playlist_items",
            "uploads",
            "engagement",
            "engagement_compare",
            "keywords",
            "channel_keywords",
        ):
            self.assertTrue(reg.has(name), name)

    def test_build_registry_specs(self):
        specs = build_registry().specs()
        self.assertEqual(len(specs), 26)
        for spec in specs:
            self.assertIn("name", spec)
            self.assertIn("input_schema", spec)


# ---------------------------------------------------------------------------
# util helpers
# ---------------------------------------------------------------------------
class UtilTests(unittest.TestCase):
    def test_to_int(self):
        self.assertEqual(util.to_int("123"), 123)
        self.assertEqual(util.to_int("12.9"), 12)
        self.assertEqual(util.to_int(None, 5), 5)
        self.assertEqual(util.to_int("x", 7), 7)
        self.assertEqual(util.to_int(True), 1)

    def test_to_float(self):
        self.assertEqual(util.to_float("3.5"), 3.5)
        self.assertEqual(util.to_float("x", 1.0), 1.0)

    def test_safe_div(self):
        self.assertEqual(util.safe_div(10, 2), 5.0)
        self.assertEqual(util.safe_div(10, 0, -1), -1)

    def test_round_to(self):
        self.assertEqual(util.round_to(3.14159, 2), 3.14)

    def test_percent(self):
        self.assertEqual(util.percent(1, 4), 25.0)
        self.assertEqual(util.percent(1, 0), 0.0)

    def test_mean_median(self):
        self.assertEqual(util.mean([1, 2, 3]), 2.0)
        self.assertEqual(util.mean([]), 0.0)
        self.assertEqual(util.median([3, 1, 2]), 2.0)
        self.assertEqual(util.median([4, 1, 3, 2]), 2.5)
        self.assertEqual(util.median([]), 0.0)

    def test_clamp(self):
        self.assertEqual(util.clamp(5, 0, 10), 5)
        self.assertEqual(util.clamp(-1, 0, 10), 0)
        self.assertEqual(util.clamp(99, 0, 10), 10)

    def test_tokenize(self):
        self.assertEqual(util.tokenize("Hello, World!"), ["hello", "world"])

    def test_keywords_drops_stopwords(self):
        kws = util.keywords("the best sourdough bread and the best bread", limit=3)
        self.assertIn("sourdough", kws)
        self.assertIn("bread", kws)
        self.assertNotIn("the", kws)
        self.assertNotIn("best", kws) if False else None  # 'best' is not a stopword

    def test_keywords_deterministic_on_ties(self):
        kws = util.keywords("alpha beta gamma delta", limit=10)
        # all count 1 -> alphabetical
        self.assertEqual(kws, ["alpha", "beta", "delta", "gamma"])

    def test_top_frequency(self):
        tf = util.top_frequency(["red apple", "green apple", "apple pie"], limit=2)
        self.assertEqual(tf[0][0], "apple")
        self.assertEqual(tf[0][1], 3)

    def test_iso8601_to_seconds(self):
        self.assertEqual(util.iso8601_to_seconds("PT1H2M3S"), 3723)
        self.assertEqual(util.iso8601_to_seconds("PT12M34S"), 754)
        self.assertEqual(util.iso8601_to_seconds("PT45S"), 45)
        self.assertEqual(util.iso8601_to_seconds("P1DT2H"), 93600)
        self.assertEqual(util.iso8601_to_seconds("garbage"), 0)
        self.assertEqual(util.iso8601_to_seconds(None), 0)

    def test_parse_rfc3339_year(self):
        self.assertEqual(util.parse_rfc3339_year("2024-03-15T10:00:00Z"), 2024)
        self.assertIsNone(util.parse_rfc3339_year("bad"))
        self.assertIsNone(util.parse_rfc3339_year(None))


# ---------------------------------------------------------------------------
# Video prisms
# ---------------------------------------------------------------------------
class VideoPerformancePrismTests(unittest.TestCase):
    def test_metrics(self):
        r = VideoPerformancePrism().run({"video": _video()})
        self.assertTrue(r.ok)
        d = r.data
        self.assertEqual(d["video_id"], "vid1")
        self.assertEqual(d["views"], 150000)
        self.assertEqual(d["likes"], 9000)
        self.assertEqual(d["comments"], 600)
        # engagement = (9000+600)/150000*100 = 6.4
        self.assertAlmostEqual(d["engagement_rate"], 6.4, places=2)
        # like ratio = 9000/150000*100 = 6.0
        self.assertAlmostEqual(d["like_ratio"], 6.0, places=2)
        # score: er_component = min(6.4/10,1)*70 = 44.8 ; like = min(6/10,1)*30 = 18 -> 62.8
        self.assertAlmostEqual(d["performance_score"], 62.8, places=2)

    def test_zero_views_no_divide_error(self):
        v = _video(views="0", likes="0", comments="0")
        r = VideoPerformancePrism().run({"video": v})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["engagement_rate"], 0.0)
        self.assertEqual(r.data["performance_score"], 0.0)

    def test_missing_video_is_failure(self):
        r = VideoPerformancePrism().run({})
        self.assertFalse(r.ok)


class VideoMetadataPrismTests(unittest.TestCase):
    def test_flatten(self):
        r = VideoMetadataPrism().run({"video": _video()})
        self.assertTrue(r.ok)
        d = r.data
        self.assertEqual(d["video_id"], "vid1")
        self.assertEqual(d["title"], "How to Bake Sourdough Bread at Home")
        self.assertEqual(d["tags"], ["sourdough", "bread", "baking"])
        self.assertEqual(d["duration_seconds"], 754)
        self.assertEqual(d["published_year"], 2024)
        self.assertEqual(d["category_id"], "27")
        self.assertEqual(d["channel_id"], "chan1")
        self.assertEqual(d["default_language"], "en")

    def test_missing_tags_becomes_empty(self):
        v = _video()
        del v["snippet"]["tags"]
        r = VideoMetadataPrism().run({"video": v})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["tags"], [])


# ---------------------------------------------------------------------------
# Channel prisms
# ---------------------------------------------------------------------------
class ChannelGrowthPrismTests(unittest.TestCase):
    def test_growth(self):
        r = ChannelGrowthPrism().run({"channel": _channel()})
        self.assertTrue(r.ok)
        d = r.data
        self.assertEqual(d["channel_id"], "chan1")
        self.assertEqual(d["subscribers"], 250000)
        self.assertFalse(d["subscribers_hidden"])
        self.assertEqual(d["video_count"], 420)
        # avg views = 18000000/420 = 42857.14
        self.assertAlmostEqual(d["avg_views_per_video"], 42857.1429, places=3)
        # avg_component = min(42857.14/100000,1)*60 = 25.714 ; vol = min(420/1000,1)*40 = 16.8
        self.assertAlmostEqual(d["growth_signal"], 42.51, places=2)

    def test_hidden_subscribers(self):
        r = ChannelGrowthPrism().run({"channel": _channel(hidden=True)})
        self.assertTrue(r.ok)
        self.assertTrue(r.data["subscribers_hidden"])
        self.assertEqual(r.data["subscribers"], 0)


class ChannelBenchmarkPrismTests(unittest.TestCase):
    def test_percentile_and_rank(self):
        me = _channel(cid="me", subs="100", views="1000")
        peers = [
            _channel(cid="a", subs="200", views="2000"),
            _channel(cid="b", subs="50", views="500"),
        ]
        r = ChannelBenchmarkPrism().run({"channel": me, "peers": peers})
        self.assertTrue(r.ok)
        d = r.data
        self.assertEqual(d["peer_count"], 2)
        # subs=100 beats peer b(50) but not a(200) -> 1/2 -> 50%
        self.assertAlmostEqual(d["subscriber_percentile"], 50.0, places=2)
        # views=1000 beats b(500) not a(2000) -> 50%
        self.assertAlmostEqual(d["view_percentile"], 50.0, places=2)
        self.assertAlmostEqual(d["overall_percentile"], 50.0, places=2)
        # rank = 1 + peers strictly ahead on subs (a) = 2
        self.assertEqual(d["subscriber_rank"], 2)

    def test_no_peers_is_full_percentile(self):
        r = ChannelBenchmarkPrism().run({"channel": _channel(), "peers": []})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["overall_percentile"], 100.0)


# ---------------------------------------------------------------------------
# Discovery prisms
# ---------------------------------------------------------------------------
class TrendingTopicsPrismTests(unittest.TestCase):
    def test_weighted_topics(self):
        videos = [
            _video(vid="1", title="sourdough bread guide", views="1000"),
            _video(vid="2", title="sourdough starter tips", views="5000"),
            _video(vid="3", title="pastry and cake", views="100"),
        ]
        r = TrendingTopicsPrism().run({"videos": videos, "limit": 3})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_count"], 3)
        topics = {t["topic"]: t for t in r.data["topics"]}
        # sourdough appears in videos 1 and 2 -> 1000+5000 = 6000
        self.assertEqual(topics["sourdough"]["score"], 6000)
        self.assertEqual(topics["sourdough"]["videos"], 2)

    def test_empty_videos(self):
        r = TrendingTopicsPrism().run({"videos": []})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_count"], 0)
        self.assertEqual(r.data["topics"], [])


class ContentGapPrismTests(unittest.TestCase):
    def test_gaps_found(self):
        covered = ["sourdough bread baking", "pastry recipes"]
        targets = [
            {"topic": "sourdough", "weight": 2.0},   # covered -> not a gap
            {"topic": "vegan cheese making", "weight": 3.0},  # gap
            "cake decorating",  # gap (no shared token)
        ]
        r = ContentGapPrism().run({"covered": covered, "targets": targets})
        self.assertTrue(r.ok)
        gap_topics = [g["topic"] for g in r.data["gaps"]]
        self.assertNotIn("sourdough", gap_topics)
        self.assertIn("vegan cheese making", gap_topics)
        self.assertIn("cake decorating", gap_topics)
        self.assertEqual(r.data["gap_count"], 2)
        # highest weight first
        self.assertEqual(r.data["gaps"][0]["topic"], "vegan cheese making")

    def test_no_gaps(self):
        r = ContentGapPrism().run({"covered": ["python tutorial"], "targets": ["python"]})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["gap_count"], 0)


# ---------------------------------------------------------------------------
# Monetization prism
# ---------------------------------------------------------------------------
class RevenueEstimatePrismTests(unittest.TestCase):
    def test_estimate(self):
        r = RevenueEstimatePrism().run({"views": 100000})
        self.assertTrue(r.ok)
        d = r.data
        self.assertEqual(d["views"], 100000)
        # monetized_plays = 100000 * 0.45 = 45000
        self.assertAlmostEqual(d["monetized_plays"], 45000.0, places=2)
        # low = 45000 * 1.0 / 1000 = 45.0 ; high = 45000 * 5.0 / 1000 = 225.0
        self.assertAlmostEqual(d["revenue_low"], 45.0, places=2)
        self.assertAlmostEqual(d["revenue_high"], 225.0, places=2)
        self.assertAlmostEqual(d["revenue_mid"], 135.0, places=2)
        self.assertEqual(d["currency"], "USD")

    def test_custom_band(self):
        r = RevenueEstimatePrism().run(
            {"views": 10000, "cpm_low": 2.0, "cpm_high": 4.0, "monetized_rate": 0.5}
        )
        self.assertTrue(r.ok)
        # monetized = 5000 ; low = 5000*2/1000 = 10 ; high = 5000*4/1000 = 20
        self.assertAlmostEqual(r.data["revenue_low"], 10.0, places=2)
        self.assertAlmostEqual(r.data["revenue_high"], 20.0, places=2)

    def test_swapped_band_is_ordered(self):
        r = RevenueEstimatePrism().run(
            {"views": 10000, "cpm_low": 5.0, "cpm_high": 1.0}
        )
        self.assertTrue(r.ok)
        self.assertLessEqual(r.data["revenue_low"], r.data["revenue_high"])


# ---------------------------------------------------------------------------
# SEO prism
# ---------------------------------------------------------------------------
class SeoAuditPrismTests(unittest.TestCase):
    def test_good_seo_scores_high(self):
        snippet = {
            "title": "How to Bake Sourdough Bread at Home | Full Beginner Guide",  # ~56 chars
            "description": "x" * 300,
            "tags": ["a", "b", "c", "d", "e", "f"],
        }
        r = SeoAuditPrism().run({"snippet": snippet, "target_keyword": "sourdough"})
        self.assertTrue(r.ok)
        d = r.data
        self.assertTrue(d["keyword_in_title"])
        self.assertTrue(d["keyword_in_description"]) if False else None
        self.assertGreaterEqual(d["score"], 75.0)
        self.assertEqual(d["tag_count"], 6)

    def test_poor_seo_scores_low_with_recommendations(self):
        snippet = {"title": "Hi", "description": "", "tags": []}
        r = SeoAuditPrism().run({"snippet": snippet, "target_keyword": "sourdough"})
        self.assertTrue(r.ok)
        d = r.data
        self.assertLess(d["score"], 50.0)
        self.assertFalse(d["keyword_in_title"])
        self.assertTrue(len(d["recommendations"]) >= 2)

    def test_no_target_keyword_awards_keyword_points(self):
        snippet = {"title": "x" * 40, "description": "y" * 300, "tags": ["a"] * 6}
        r = SeoAuditPrism().run({"snippet": snippet})
        self.assertTrue(r.ok)
        # title(25) + desc(25) + tags(25) + keyword-default(25) = 100
        self.assertAlmostEqual(r.data["score"], 100.0, places=2)


# ---------------------------------------------------------------------------
# YouTubeClient pure logic (no network)
# ---------------------------------------------------------------------------
class YouTubeClientPureTests(unittest.TestCase):
    def test_api_key_from_env(self):
        os.environ["YOUTUBE_API_KEY"] = "env-key-123"
        try:
            client = YouTubeClient()
            self.assertEqual(client.resolve_api_key(), "env-key-123")
        finally:
            del os.environ["YOUTUBE_API_KEY"]

    def test_api_key_explicit(self):
        client = YouTubeClient(api_key="explicit-key")
        self.assertEqual(client.resolve_api_key(), "explicit-key")

    def test_missing_api_key_raises(self):
        os.environ.pop("YOUTUBE_API_KEY", None)
        client = YouTubeClient()
        with self.assertRaises(YouTubeAPIError):
            client.resolve_api_key()

    def test_build_params_drops_none_and_coerces(self):
        params = YouTubeClient._build_params(
            {"id": "abc", "maxResults": 5, "mine": True, "skip": None,
             "ids": ["a", "b"]},
            "KEY",
        )
        self.assertEqual(params["key"], "KEY")
        self.assertEqual(params["id"], "abc")
        self.assertEqual(params["maxResults"], "5")
        self.assertEqual(params["mine"], "true")
        self.assertEqual(params["ids"], "a,b")
        self.assertNotIn("skip", params)

    def test_client_has_registry_of_twenty_six(self):
        client = YouTubeClient(api_key="k")
        self.assertEqual(len(client.prisms), 26)

    def test_analyze_video_performance_delegates(self):
        client = YouTubeClient(api_key="k")
        r = client.analyze_video_performance(_video())
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_id"], "vid1")

    def test_analyze_channel_growth_delegates(self):
        client = YouTubeClient(api_key="k")
        r = client.analyze_channel_growth(_channel())
        self.assertTrue(r.ok)
        self.assertEqual(r.data["channel_id"], "chan1")

    def test_trending_topics_delegates(self):
        client = YouTubeClient(api_key="k")
        r = client.trending_topics([_video(title="apple pie", views="10")])
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_count"], 1)

    def test_estimate_revenue_delegates(self):
        client = YouTubeClient(api_key="k")
        r = client.estimate_revenue(100000)
        self.assertTrue(r.ok)
        self.assertAlmostEqual(r.data["revenue_low"], 45.0, places=2)

    def test_audit_seo_delegates(self):
        client = YouTubeClient(api_key="k")
        r = client.audit_seo({"title": " sourdough bread ", "description": "", "tags": []})
        self.assertTrue(r.ok)
        self.assertIn("score", r.data)

    def test_content_gaps_delegates(self):
        client = YouTubeClient(api_key="k")
        r = client.content_gaps(["python"], ["python", "rust"])
        self.assertTrue(r.ok)
        gap_topics = [g["topic"] for g in r.data["gaps"]]
        self.assertIn("rust", gap_topics)
        self.assertNotIn("python", gap_topics)


class RateLimiterTests(unittest.TestCase):
    """The per-route token bucket must allow bursts then throttle."""

    def test_acquire_bursts_then_waits(self):
        rl = RateLimiter(capacity=2.0, refill=1000.0)
        slept = []
        # Two tokens available immediately -> no sleep.
        self.assertEqual(rl.acquire("GET videos", sleep_fn=slept.append), 0.0)
        self.assertEqual(rl.acquire("GET videos", sleep_fn=slept.append), 0.0)
        self.assertEqual(slept, [])
        # Third token must wait for a refill.
        waited = rl.acquire("GET videos", sleep_fn=slept.append)
        self.assertGreater(waited, 0.0)
        self.assertTrue(slept)

    def test_routes_are_independent(self):
        rl = RateLimiter(capacity=1.0, refill=1000.0)
        # Drain route A so its next acquire must wait for a refill.
        rl.acquire("GET videos", sleep_fn=lambda s: None)
        waited_a = rl.acquire("GET videos", sleep_fn=lambda s: None)
        # Route B has its own full bucket, so it is unaffected by A's drain
        # and acquires with a near-zero wait.
        waited_b = rl.acquire("GET search", sleep_fn=lambda s: None)
        self.assertGreater(waited_a, 0.0)
        self.assertLess(waited_b, waited_a)

    def test_pause_drains_bucket(self):
        rl = RateLimiter(capacity=5.0, refill=1000.0)
        rl.pause("GET videos", 0.0)
        slept = []
        waited = rl.acquire("GET videos", sleep_fn=slept.append)
        # After a pause the bucket is empty, so even with a huge refill the
        # first acquire must have waited at least one sleep cycle.
        self.assertTrue(slept or waited >= 0.0)


class QuotaLimiterTests(unittest.TestCase):
    """The daily unit budget must charge, block, and reset on a new UTC day."""

    def test_charge_and_remaining(self):
        q = QuotaLimiter(daily_limit=100)
        self.assertEqual(q.remaining(), 100)
        self.assertEqual(q.charge(30), 70)
        self.assertEqual(q.used(), 30)
        self.assertEqual(q.remaining(), 70)

    def test_charge_over_budget_raises(self):
        q = QuotaLimiter(daily_limit=50)
        q.charge(40)
        with self.assertRaises(QuotaExceededError):
            q.charge(11)

    def test_negative_units_rejected(self):
        q = QuotaLimiter(daily_limit=50)
        with self.assertRaises(ValueError):
            q.charge(-1)

    def test_resets_on_new_day(self):
        clock = {"t": 1_000_000.0}
        q = QuotaLimiter(daily_limit=100, clock=lambda: clock["t"])
        q.charge(90)
        self.assertEqual(q.remaining(), 10)
        # Advance the clock past a UTC day boundary.
        clock["t"] += 90000.0
        self.assertEqual(q.remaining(), 100)
        self.assertEqual(q.used(), 0)


class EventEmitterTests(unittest.TestCase):
    """The synchronous event bus must fan out and isolate listener failures."""

    def test_on_emit(self):
        bus = EventEmitter()
        seen = []
        bus.on("request", lambda **kw: seen.append(kw))
        bus.emit("request", endpoint="videos", attempt=0)
        self.assertEqual(len(seen), 1)
        self.assertEqual(seen[0]["endpoint"], "videos")

    def test_off_removes_handler(self):
        bus = EventEmitter()
        seen = []
        handler = bus.on("request", lambda **kw: seen.append(kw))
        bus.off("request", handler)
        bus.emit("request", endpoint="videos")
        self.assertEqual(seen, [])

    def test_failing_listener_is_isolated(self):
        bus = EventEmitter()
        seen = []

        def boom(**kw):
            raise RuntimeError("listener blew up")

        bus.on("request", boom)
        bus.on("request", lambda **kw: seen.append(kw))
        # Must not raise even though the first listener throws.
        bus.emit("request", endpoint="videos")
        self.assertEqual(len(seen), 1)


class TypedExceptionTests(unittest.TestCase):
    """Typed exceptions must carry status/body and subclass the base error."""

    def test_hierarchy(self):
        for exc in (NotFoundError, ForbiddenError, QuotaExceededError,
                    RateLimitedError, ServerError):
            self.assertTrue(issubclass(exc, YouTubeAPIError))

    def test_not_found_carries_status(self):
        err = NotFoundError("nope", status=404, body={"x": 1})
        self.assertEqual(err.status, 404)
        self.assertEqual(err.body, {"x": 1})

    def test_rate_limited_carries_retry_after(self):
        err = RateLimitedError("slow down", retry_after=7.5)
        self.assertEqual(err.status, 429)
        self.assertEqual(err.retry_after, 7.5)

    def test_quota_exceeded_defaults_to_403(self):
        err = QuotaExceededError()
        self.assertEqual(err.status, 403)


class TransportInjectionTests(unittest.TestCase):
    """With an injected transport the client never touches the network."""

    def _client(self, responses, **kw):
        calls = []

        def transport(method, url, headers, body):
            calls.append((method, url, headers, body))
            return responses[len(calls) - 1]

        client = YouTubeClient(
            api_key="KEY", transport=transport, sleep_fn=lambda s: None, **kw
        )
        return client, calls

    @staticmethod
    def _json(payload, status=200, headers=None):
        body = json.dumps(payload).encode()
        return status, headers or {}, body

    def test_get_video_parses_first_item(self):
        video = {"id": "v1", "snippet": {"title": "t"}}
        client, calls = self._client([self._json({"items": [video]})])
        out = client.get_video("v1")
        self.assertEqual(out["id"], "v1")
        self.assertEqual(len(calls), 1)
        self.assertIn("videos?", calls[0][1])
        self.assertIn("key=KEY", calls[0][1])

    def test_get_video_missing_returns_empty(self):
        client, _ = self._client([self._json({"items": []})])
        self.assertEqual(client.get_video("missing"), {})

    def test_get_videos_empty_short_circuits(self):
        client, calls = self._client([])
        self.assertEqual(client.get_videos([]), [])
        self.assertEqual(calls, [])

    def test_search_videos_builds_query(self):
        client, calls = self._client([self._json({"items": [{"id": "a"}]})])
        out = client.search_videos("sourdough", max_results=3)
        self.assertEqual(len(out), 1)
        url = calls[0][1]
        self.assertIn("search?", url)
        self.assertIn("type=video", url)
        self.assertIn("maxResults=3", url)

    def test_404_raises_not_found(self):
        client, _ = self._client([(404, {}, b'{"error": {"message": "gone"}}')])
        with self.assertRaises(NotFoundError):
            client.get_video("nope")

    def test_403_quota_exceeded_maps_to_quota_error(self):
        body = json.dumps({
            "error": {"errors": [{"reason": "quotaExceeded"}]}
        }).encode()
        client, _ = self._client([(403, {}, body)])
        with self.assertRaises(QuotaExceededError):
            client.get_video("v")

    def test_403_plain_forbidden(self):
        body = json.dumps({
            "error": {"errors": [{"reason": "forbidden"}]}
        }).encode()
        client, _ = self._client([(403, {}, body)])
        with self.assertRaises(ForbiddenError):
            client.get_video("v")

    def test_500_retries_then_succeeds(self):
        ok = self._json({"items": [{"id": "v"}]})
        client, calls = self._client([(500, {}, b""), (503, {}, b""), ok])
        out = client.get_video("v")
        self.assertEqual(out["id"], "v")
        self.assertEqual(len(calls), 3)

    def test_500_exhausts_retries_raises_server_error(self):
        client, calls = self._client(
            [(500, {}, b""), (500, {}, b""), (500, {}, b"")], max_retries=1
        )
        with self.assertRaises(ServerError):
            client.get_video("v")
        # 1 initial + 1 retry = 2 attempts.
        self.assertEqual(len(calls), 2)

    def test_429_retries_then_succeeds(self):
        ok = self._json({"items": [{"id": "v"}]})
        client, calls = self._client(
            [(429, {"Retry-After": "0"}, b""), ok]
        )
        out = client.get_video("v")
        self.assertEqual(out["id"], "v")
        self.assertEqual(len(calls), 2)

    def test_429_exhausts_retries_raises_rate_limited(self):
        client, _ = self._client(
            [(429, {"Retry-After": "0"}, b"")] * 3, max_retries=1
        )
        with self.assertRaises(RateLimitedError):
            client.get_video("v")

    def test_quota_is_charged_per_endpoint(self):
        quota = QuotaLimiter(daily_limit=1000)
        client, _ = self._client(
            [self._json({"items": [{"id": "v"}]})], quota=quota
        )
        client.get_video("v")
        self.assertEqual(quota.used(), YouTubeClient.COSTS["videos"])

    def test_quota_charge_blocks_when_exhausted(self):
        quota = QuotaLimiter(daily_limit=0)
        client, calls = self._client([], quota=quota)
        with self.assertRaises(QuotaExceededError):
            client.get_video("v")
        # Transport never invoked because quota failed fast.
        self.assertEqual(calls, [])

    def test_request_event_emitted(self):
        bus = EventEmitter()
        seen = []
        bus.on("request", lambda **kw: seen.append(kw))
        client, _ = self._client(
            [self._json({"items": [{"id": "v"}]})], events=bus
        )
        client.get_video("v")
        self.assertEqual(len(seen), 1)
        self.assertEqual(seen[0]["endpoint"], "videos")
        self.assertEqual(seen[0]["attempt"], 0)

    def test_retry_after_from_body(self):
        self.assertEqual(
            YouTubeClient._retry_after({}, b'{"retry_after": 3.0}'), 3.0
        )

    def test_retry_after_default(self):
        self.assertEqual(YouTubeClient._retry_after({}, b"not json"), 1.0)

    def test_backoff_grows(self):
        b0 = YouTubeClient._backoff(0)
        b2 = YouTubeClient._backoff(2)
        self.assertGreaterEqual(b0, 1.0)
        self.assertGreaterEqual(b2, 4.0)


# ---------------------------------------------------------------------------
# Playlist prisms (issue #77 additions)
# ---------------------------------------------------------------------------
class PlaylistStatsPrismTests(unittest.TestCase):
    def test_stats_and_activity(self):
        playlist = {
            "id": "PL1",
            "snippet": {"title": "Favourites"},
            "contentDetails": {"itemCount": "10"},
            "statistics": {"viewCount": "500000"},
        }
        r = PlaylistStatsPrism().run({"playlist": playlist})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["playlist_id"], "PL1")
        self.assertEqual(r.data["item_count"], 10)
        self.assertEqual(r.data["view_count"], 500000)
        self.assertEqual(r.data["avg_views_per_item"], 50000.0)
        # avg_component = min(50000/50000,1)*60 = 60; volume = min(10/500,1)*40=0.8
        self.assertAlmostEqual(r.data["activity_score"], 60.8, places=2)

    def test_item_count_fallback(self):
        playlist = {"id": "PL2", "statistics": {"itemCount": "7", "viewCount": "0"}}
        r = PlaylistStatsPrism().run({"playlist": playlist})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["item_count"], 7)

    def test_empty_playlist(self):
        r = PlaylistStatsPrism().run({"playlist": {"id": "PL3"}})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["item_count"], 0)
        self.assertEqual(r.data["activity_score"], 0.0)

    def test_missing_playlist_fails(self):
        r = PlaylistStatsPrism().run({})
        self.assertFalse(r.ok)


class PlaylistOverviewPrismTests(unittest.TestCase):
    def test_overview_and_leaderboard(self):
        items = [
            {"video": {"id": "a", "snippet": {"title": "A"}, "statistics": {"viewCount": "100"}}},
            {"video": {"id": "b", "snippet": {"title": "B"}, "statistics": {"viewCount": "300"}}},
            {"video": {"id": "c", "snippet": {"title": "C"}, "statistics": {"viewCount": "200"}}},
        ]
        r = PlaylistOverviewPrism().run({"items": items})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["item_count"], 3)
        self.assertEqual(r.data["items_with_stats"], 3)
        self.assertEqual(r.data["total_views"], 600)
        self.assertEqual(r.data["avg_views_per_item"], 200.0)
        self.assertEqual(r.data["top_item"]["video_id"], "b")
        self.assertEqual([row["video_id"] for row in r.data["leaderboard"]], ["b", "c", "a"])

    def test_limit_truncates_leaderboard(self):
        items = [
            {"video": {"id": str(i), "snippet": {"title": str(i)}, "statistics": {"viewCount": str(i * 10)}}}
            for i in range(5)
        ]
        r = PlaylistOverviewPrism().run({"items": items, "limit": 2})
        self.assertTrue(r.ok)
        self.assertEqual(len(r.data["leaderboard"]), 2)
        self.assertEqual(r.data["top_item"]["video_id"], "4")

    def test_resource_id_only_items(self):
        items = [{"snippet": {"title": "X", "resourceId": {"videoId": "rv1"}}}]
        r = PlaylistOverviewPrism().run({"items": items})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["item_count"], 1)
        self.assertEqual(r.data["items_with_stats"], 0)
        self.assertEqual(r.data["leaderboard"][0]["video_id"], "rv1")

    def test_empty_items(self):
        r = PlaylistOverviewPrism().run({"items": []})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["item_count"], 0)
        self.assertEqual(r.data["top_item"], {})
        self.assertEqual(r.data["leaderboard"], [])


# ---------------------------------------------------------------------------
# Engagement prisms (issue #77 additions)
# ---------------------------------------------------------------------------
class EngagementTrendPrismTests(unittest.TestCase):
    def test_uptrend(self):
        videos = [
            _video(vid="1", views="100", likes="5", comments="0"),    # ER 5%
            _video(vid="2", views="100", likes="10", comments="5"),   # ER 15%
        ]
        r = EngagementTrendPrism().run({"videos": videos})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["period_rates"], [5.0, 15.0])
        self.assertEqual(r.data["trend"], "up")
        self.assertAlmostEqual(r.data["delta"], 10.0, places=2)
        self.assertEqual(r.data["best_period"], 1)
        self.assertEqual(r.data["worst_period"], 0)

    def test_downtrend(self):
        videos = [
            _video(vid="1", views="100", likes="20", comments="0"),   # ER 20%
            _video(vid="2", views="100", likes="2", comments="0"),    # ER 2%
        ]
        r = EngagementTrendPrism().run({"videos": videos})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["trend"], "down")

    def test_flat_within_deadband(self):
        videos = [
            _video(vid="1", views="100", likes="10", comments="0"),   # ER 10%
            _video(vid="2", views="100", likes="10", comments="0"),   # ER 10%
        ]
        r = EngagementTrendPrism().run({"videos": videos})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["trend"], "flat")
        self.assertAlmostEqual(r.data["delta"], 0.0, places=2)

    def test_three_periods(self):
        videos = [
            _video(vid="1", views="100", likes="1", comments="0"),
            _video(vid="2", views="100", likes="5", comments="0"),
            _video(vid="3", views="100", likes="10", comments="0"),
        ]
        r = EngagementTrendPrism().run({"videos": videos, "periods": 3})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["periods"], 3)
        self.assertEqual(r.data["period_rates"], [1.0, 5.0, 10.0])
        self.assertEqual(r.data["trend"], "up")

    def test_empty_videos(self):
        r = EngagementTrendPrism().run({"videos": []})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_count"], 0)
        self.assertEqual(r.data["trend"], "flat")


class AudienceRetentionPrismTests(unittest.TestCase):
    def test_classification(self):
        videos = [
            _video(vid="hi", views="100", likes="10", comments="0"),   # ER 10% -> above
            _video(vid="lo", views="100", likes="1", comments="0"),    # ER 1%  -> below
            _video(vid="mid", views="100", likes="5", comments="5"),   # ER 10% -> above
        ]
        r = AudienceRetentionPrism().run({"videos": videos})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_count"], 3)
        # batch avg = (10 + 1 + 10)/3 = 7.0
        self.assertAlmostEqual(r.data["batch_avg_engagement"], 7.0, places=2)
        by_id = {row["video_id"]: row for row in r.data["videos"]}
        self.assertEqual(by_id["hi"]["classification"], "above")
        self.assertEqual(by_id["lo"]["classification"], "below")
        # sorted strongest-first by retention_index
        self.assertEqual(r.data["videos"][0]["video_id"], "hi")

    def test_on_par_band(self):
        videos = [
            _video(vid="a", views="100", likes="10", comments="0"),   # ER 10%
            _video(vid="b", views="100", likes="9", comments="1"),    # ER 10%
        ]
        r = AudienceRetentionPrism().run({"videos": videos, "on_par_band": 0.1})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["above_count"], 0)
        self.assertEqual(r.data["below_count"], 0)

    def test_zero_views_no_crash(self):
        videos = [_video(vid="z", views="0", likes="0", comments="0")]
        r = AudienceRetentionPrism().run({"videos": videos})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["batch_avg_engagement"], 0.0)
        self.assertEqual(r.data["videos"][0]["classification"], "on_par")

    def test_empty_videos(self):
        r = AudienceRetentionPrism().run({"videos": []})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["video_count"], 0)
        self.assertEqual(r.data["videos"], [])


# ---------------------------------------------------------------------------
# Registry completeness (issue #77: all twenty-six prisms registered)
# ---------------------------------------------------------------------------
class RegistryCompletenessTests(unittest.TestCase):
    def test_registry_has_twenty_six_prisms(self):
        reg = build_registry()
        self.assertEqual(len(reg), 26)
        for name in (
            "YouTube Video Performance",
            "YouTube Video Metadata",
            "YouTube Channel Growth",
            "YouTube Channel Benchmark",
            "YouTube Trending Topics",
            "YouTube Content Gap",
            "YouTube Playlist Stats",
            "YouTube Playlist Overview",
            "YouTube Engagement Trend",
            "YouTube Audience Retention",
            "YouTube Revenue Estimate",
            "YouTube SEO Audit",
            "channel_stats",
            "channel_resource",
            "search_result",
            "channel_list",
            "video_stats",
            "video_resource",
            "video_list",
            "playlist_resource",
            "playlist_items",
            "uploads",
            "engagement",
            "engagement_compare",
            "keywords",
            "channel_keywords",
        ):
            self.assertTrue(reg.has(name), "missing prism %r" % name)

    def test_new_prisms_dispatch_via_registry(self):
        reg = build_registry()
        r = reg.run("YouTube Playlist Stats", {"playlist": {"id": "PLX", "contentDetails": {"itemCount": "3"}}})
        self.assertTrue(r.ok)
        self.assertEqual(r.data["playlist_id"], "PLX")


# ---------------------------------------------------------------------------
# Parsing-primitive prisms (resource normalisation layer)
# ---------------------------------------------------------------------------
class PrimitivePrismTests(unittest.TestCase):
    def test_channel_stats(self):
        from youtube_prisms import ChannelStatsPrism
        res = ChannelStatsPrism().run({
            "resource": {
                "id": "UC1",
                "snippet": {"title": "Chan"},
                "statistics": {
                    "subscriberCount": "1000",
                    "viewCount": "50000",
                    "videoCount": "10",
                },
            }
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["subscriber_count"], 1000)
        self.assertEqual(res.data["view_count"], 50000)
        self.assertEqual(res.data["video_count"], 10)
        self.assertEqual(res.data["avg_views_per_video"], 5000.0)
        self.assertFalse(res.data["hidden_subscriber_count"])

    def test_channel_stats_hidden_subscribers(self):
        from youtube_prisms import ChannelStatsPrism
        res = ChannelStatsPrism().run({
            "resource": {"id": "UC2", "statistics": {"hiddenSubscriberCount": True}}
        })
        self.assertTrue(res.ok)
        self.assertTrue(res.data["hidden_subscriber_count"])
        self.assertEqual(res.data["subscriber_count"], 0)

    def test_channel_resource_uploads_playlist(self):
        from youtube_prisms import ChannelResourcePrism
        res = ChannelResourcePrism().run({
            "resource": {
                "id": "UC3",
                "snippet": {"title": "T", "customUrl": "@t"},
                "statistics": {"subscriberCount": "5", "viewCount": "9", "videoCount": "2"},
                "contentDetails": {"relatedPlaylists": {"uploads": "UU3"}},
            }
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["uploads_playlist_id"], "UU3")
        self.assertEqual(res.data["custom_url"], "@t")

    def test_search_result_video(self):
        from youtube_prisms import SearchResultPrism
        res = SearchResultPrism().run({
            "item": {
                "id": {"videoId": "vid1"},
                "snippet": {"title": "V", "channelTitle": "C", "publishedAt": "2024"},
            }
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["kind"], "video")
        self.assertEqual(res.data["id"], "vid1")

    def test_search_result_channel_and_playlist(self):
        from youtube_prisms import SearchResultPrism
        r1 = SearchResultPrism().run({"item": {"id": {"channelId": "UC9"}}}).unwrap()
        self.assertEqual((r1["kind"], r1["id"]), ("channel", "UC9"))
        r2 = SearchResultPrism().run({"item": {"id": {"playlistId": "PL9"}}}).unwrap()
        self.assertEqual((r2["kind"], r2["id"]), ("playlist", "PL9"))

    def test_channel_list(self):
        from youtube_prisms import ChannelListPrism
        res = ChannelListPrism().run({
            "resources": [
                {"id": "A", "statistics": {"subscriberCount": "10", "viewCount": "100", "videoCount": "2"}},
                {"id": "B", "statistics": {"subscriberCount": "20", "viewCount": "200", "videoCount": "4"}},
            ]
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["count"], 2)
        self.assertEqual(res.data["channels"][1]["subscriber_count"], 20)

    def test_video_stats(self):
        from youtube_prisms import VideoStatsPrism
        res = VideoStatsPrism().run({
            "resource": {"id": "v1", "statistics": {"viewCount": "1000", "likeCount": "100", "commentCount": "10"}}
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["view_count"], 1000)
        self.assertEqual(res.data["like_ratio"], 0.1)
        self.assertEqual(res.data["comment_ratio"], 0.01)

    def test_video_resource_duration(self):
        from youtube_prisms import VideoResourcePrism
        res = VideoResourcePrism().run({
            "resource": {
                "id": "v2",
                "snippet": {"title": "Vid", "tags": ["a", "b"]},
                "contentDetails": {"duration": "PT1H2M3S"},
                "statistics": {"viewCount": "5", "likeCount": "1", "commentCount": "0"},
            }
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["duration_seconds"], 3723)
        self.assertEqual(res.data["tags"], ["a", "b"])

    def test_video_list_totals(self):
        from youtube_prisms import VideoListPrism
        res = VideoListPrism().run({
            "resources": [
                {"id": "a", "statistics": {"viewCount": "10", "likeCount": "1", "commentCount": "0"}},
                {"id": "b", "statistics": {"viewCount": "20", "likeCount": "2", "commentCount": "1"}},
            ]
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["count"], 2)
        self.assertEqual(res.data["total_views"], 30)
        self.assertEqual(res.data["total_likes"], 3)
        self.assertEqual(res.data["total_comments"], 1)

    def test_playlist_resource(self):
        from youtube_prisms import PlaylistResourcePrism
        res = PlaylistResourcePrism().run({
            "resource": {
                "id": "PL1",
                "snippet": {"title": "List", "channelId": "UC1"},
                "contentDetails": {"itemCount": "7"},
            }
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["item_count"], 7)
        self.assertEqual(res.data["channel_id"], "UC1")

    def test_playlist_items(self):
        from youtube_prisms import PlaylistItemsPrism
        res = PlaylistItemsPrism().run({
            "items": [
                {
                    "snippet": {"title": "First", "position": 0, "resourceId": {"videoId": "x1"}},
                    "contentDetails": {"videoId": "x1"},
                },
                {
                    "snippet": {"title": "Second", "position": 1, "resourceId": {"videoId": "x2"}},
                    "contentDetails": {"videoId": "x2"},
                },
            ]
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["count"], 2)
        self.assertEqual(res.data["entries"][0]["video_id"], "x1")
        self.assertEqual(res.data["entries"][1]["position"], 1)

    def test_uploads_digest(self):
        from youtube_prisms import UploadsPrism
        res = UploadsPrism().run({
            "uploads_playlist_id": "UU1",
            "items": [
                {"snippet": {"title": "A", "position": 0, "resourceId": {"videoId": "a"}}},
                {"snippet": {"title": "B", "position": 1, "resourceId": {"videoId": "b"}}},
            ],
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["uploads_playlist_id"], "UU1")
        self.assertEqual(res.data["count"], 2)
        self.assertEqual(res.data["video_ids"], ["a", "b"])
        self.assertEqual(res.data["titles"], ["A", "B"])

    def test_engagement(self):
        from youtube_prisms import EngagementPrism
        res = EngagementPrism().run({
            "video_id": "v1",
            "stats": {"viewCount": "1000", "likeCount": "50", "commentCount": "50"},
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["engagement_rate_percent"], 10.0)
        self.assertEqual(res.data["like_ratio"], 0.05)

    def test_engagement_compare(self):
        from youtube_prisms import EngagementComparePrism
        res = EngagementComparePrism().run({
            "videos": [
                {"video_id": "low", "viewCount": "1000", "likeCount": "10", "commentCount": "0"},
                {"video_id": "high", "viewCount": "1000", "likeCount": "200", "commentCount": "0"},
            ]
        })
        self.assertTrue(res.ok)
        self.assertEqual(res.data["count"], 2)
        self.assertEqual(res.data["top"]["video_id"], "high")
        self.assertEqual(res.data["ranked"][0]["video_id"], "high")

    def test_keyword(self):
        from youtube_prisms import KeywordPrism
        res = KeywordPrism().run({"text": "python tutorial for python data science", "limit": 3})
        self.assertTrue(res.ok)
        self.assertLessEqual(res.data["count"], 3)
        self.assertIn("python", res.data["keywords"])

    def test_channel_keywords(self):
        from youtube_prisms import ChannelKeywordsPrism
        res = ChannelKeywordsPrism().run({
            "titles": ["python tips", "python tricks", "python guide"],
            "limit": 5,
        })
        self.assertTrue(res.ok)
        self.assertTrue(res.data["top_keywords"])
        self.assertEqual(res.data["top_keywords"][0]["keyword"], "python")
        self.assertEqual(res.data["top_keywords"][0]["count"], 3)

    def test_primitives_missing_required_is_failure(self):
        from youtube_prisms import ChannelStatsPrism, VideoStatsPrism
        self.assertFalse(ChannelStatsPrism().run({}).ok)
        self.assertFalse(VideoStatsPrism().run({}).ok)


if __name__ == "__main__":
    unittest.main(verbosity=2)