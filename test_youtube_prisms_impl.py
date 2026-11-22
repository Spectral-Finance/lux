"""
Stdlib-only unit tests for the YouTube Prism architecture (Spectral-Finance/lux #74).

Exercises the Prism architecture (Prism / PrismInput / PrismResult /
PrismRegistry) and every concrete YouTube prism (channel / video / playlist /
engagement / keywords) plus the youtube_client integration layer's pure
helpers — ALL without any network access. Run with:

    python3 -m unittest test_youtube_prisms_impl -v
    # or simply
    python3 test_youtube_prisms_impl.py

No third-party dependencies. No sockets are opened.
"""

import os
import unittest

import youtube_client
from youtube_prisms import (
    ChannelKeywordsPrism,
    ChannelListPrism,
    ChannelResourcePrism,
    ChannelStatsPrism,
    EngagementComparePrism,
    EngagementPrism,
    KeywordPrism,
    PlaylistItemsPrism,
    PlaylistResourcePrism,
    Prism,
    PrismError,
    PrismInput,
    PrismRegistry,
    PrismResult,
    SearchResultPrism,
    UploadsPrism,
    VideoListPrism,
    VideoResourcePrism,
    VideoStatsPrism,
    build_registry,
)
from youtube_prisms.util import (
    keywords,
    percent,
    round_to,
    safe_div,
    to_float,
    to_int,
    tokenize,
    top_frequency,
)
from youtube_prisms.video import _iso8601_to_seconds


# --------------------------------------------------------------------------- #
# Fixtures — realistic YouTube Data API v3 resource shapes (no network).
# --------------------------------------------------------------------------- #

CHANNEL_RESOURCE = {
    "kind": "youtube#channel",
    "id": "UC_x5XG1OV2P6uZZ5FSM9Ttw",
    "snippet": {
        "title": "Google for Developers",
        "description": "Champions for developers",
        "customUrl": "@googledevelopers",
        "publishedAt": "2007-08-23T00:34:43Z",
        "country": "US",
    },
    "statistics": {
        "subscriberCount": "2350000",
        "viewCount": "284741235",
        "videoCount": "6234",
        "hiddenSubscriberCount": False,
    },
    "contentDetails": {
        "relatedPlaylists": {"uploads": "UU_x5XG1OV2P6uZZ5FSM9Ttw"}
    },
}

VIDEO_RESOURCE = {
    "kind": "youtube#video",
    "id": "dQw4w9WgXcQ",
    "snippet": {
        "title": "Build a web app with Google Cloud Run",
        "description": "Learn to ship apps fast with Cloud Run.",
        "channelId": "UC_x5XG1OV2P6uZZ5FSM9Ttw",
        "channelTitle": "Google for Developers",
        "publishedAt": "2024-05-01T12:00:00Z",
        "categoryId": "28",
        "tags": ["cloud", "web", "tutorial"],
    },
    "statistics": {
        "viewCount": "150000",
        "likeCount": "9000",
        "commentCount": "600",
    },
    "contentDetails": {"duration": "PT1H2M3S"},
}

PLAYLIST_RESOURCE = {
    "kind": "youtube#playlist",
    "id": "PL123",
    "snippet": {
        "title": "Cloud tutorials",
        "description": "All cloud tutorials",
        "channelId": "UC_x5XG1OV2P6uZZ5FSM9Ttw",
        "channelTitle": "Google for Developers",
        "publishedAt": "2024-01-01T00:00:00Z",
    },
    "contentDetails": {"itemCount": "42"},
}

PLAYLIST_ITEMS_RESPONSE = {
    "kind": "youtube#playlistItemListResponse",
    "items": [
        {
            "snippet": {
                "title": "Intro to Cloud Run",
                "position": 0,
                "publishedAt": "2024-05-01T12:00:00Z",
                "resourceId": {"kind": "youtube#video", "videoId": "vid001"},
            },
            "contentDetails": {
                "videoId": "vid001",
                "videoPublishedAt": "2024-05-01T12:00:00Z",
            },
        },
        {
            "snippet": {
                "title": "Deploying to Cloud Run",
                "position": 1,
                "publishedAt": "2024-05-02T12:00:00Z",
                "resourceId": {"kind": "youtube#video", "videoId": "vid002"},
            },
            "contentDetails": {
                "videoId": "vid002",
                "videoPublishedAt": "2024-05-02T12:00:00Z",
            },
        },
    ],
}

SEARCH_VIDEO_ITEM = {
    "kind": "youtube#searchResult",
    "id": {"kind": "youtube#video", "videoId": "abc123"},
    "snippet": {
        "title": "Intro to Kubernetes",
        "channelTitle": "Tech Channel",
        "publishedAt": "2024-03-01T00:00:00Z",
        "description": "K8s basics",
    },
}

SEARCH_CHANNEL_ITEM = {
    "kind": "youtube#searchResult",
    "id": {"kind": "youtube#channel", "channelId": "UCxyz"},
    "snippet": {"title": "Tech Channel", "channelTitle": "Tech Channel"},
}


# --------------------------------------------------------------------------- #
# Architecture: PrismInput
# --------------------------------------------------------------------------- #

class PrismInputTests(unittest.TestCase):
    def test_wraps_dict_and_typed_accessors(self):
        inp = PrismInput({"a": "42", "b": 3.5, "c": [1, 2], "d": {"x": 1}})
        self.assertEqual(inp.get_str("a"), "42")
        self.assertEqual(inp.get_int("a"), 42)
        self.assertEqual(inp.get_float("b"), 3.5)
        self.assertEqual(inp.get_list("c"), [1, 2])
        self.assertEqual(inp.get_dict("d"), {"x": 1})

    def test_missing_keys_return_defaults(self):
        inp = PrismInput({})
        self.assertEqual(inp.get_str("nope"), "")
        self.assertEqual(inp.get_int("nope", 7), 7)
        self.assertEqual(inp.get_float("nope", 1.5), 1.5)
        self.assertEqual(inp.get_list("nope"), [])
        self.assertEqual(inp.get_dict("nope"), {})
        self.assertFalse(inp.has("nope"))

    def test_bad_int_string_falls_back(self):
        inp = PrismInput({"n": "not-a-number"})
        self.assertEqual(inp.get_int("n", 5), 5)

    def test_none_params_becomes_empty(self):
        inp = PrismInput(None)
        self.assertEqual(inp.raw(), {})

    def test_non_dict_raises(self):
        with self.assertRaises(PrismError):
            PrismInput(["not", "a", "dict"])


# --------------------------------------------------------------------------- #
# Architecture: PrismResult
# --------------------------------------------------------------------------- #

class PrismResultTests(unittest.TestCase):
    def test_ok_result_to_dict(self):
        r = PrismResult({"k": "v"})
        self.assertTrue(r.ok)
        self.assertEqual(r.to_dict(), {"ok": True, "data": {"k": "v"}})

    def test_errors_and_meta_serialised(self):
        r = PrismResult(ok=False, errors=["bad"], meta={"prism": "x"})
        d = r.to_dict()
        self.assertFalse(d["ok"])
        self.assertEqual(d["errors"], ["bad"])
        self.assertEqual(d["meta"], {"prism": "x"})

    def test_unwrap_raises_on_error(self):
        r = PrismResult(ok=False, errors=["boom"])
        with self.assertRaises(PrismError):
            r.unwrap()

    def test_unwrap_returns_data_on_ok(self):
        r = PrismResult({"a": 1})
        self.assertEqual(r.unwrap(), {"a": 1})


# --------------------------------------------------------------------------- #
# Architecture: Prism base + PrismRegistry
# --------------------------------------------------------------------------- #

class _AdderPrism(Prism):
    name = "adder"

    def run(self, inp):
        return PrismResult({"sum": inp.get_int("a") + inp.get_int("b")})


class PrismBaseTests(unittest.TestCase):
    def test_call_returns_prism_result(self):
        res = _AdderPrism()({"a": 2, "b": 3})
        self.assertIsInstance(res, PrismResult)
        self.assertEqual(res.unwrap()["sum"], 5)

    def test_call_accepts_prism_input(self):
        res = _AdderPrism()(PrismInput({"a": 10, "b": 5}))
        self.assertEqual(res.unwrap()["sum"], 15)

    def test_base_run_not_implemented(self):
        with self.assertRaises(NotImplementedError):
            Prism().run(PrismInput({}))


class PrismRegistryTests(unittest.TestCase):
    def test_register_and_run_by_name(self):
        reg = PrismRegistry()
        reg.register(_AdderPrism())
        self.assertTrue(reg.has("adder"))
        self.assertEqual(reg.run("adder", {"a": 4, "b": 6}).unwrap()["sum"], 10)

    def test_unknown_name_raises(self):
        reg = PrismRegistry()
        with self.assertRaises(PrismError):
            reg.get("missing")

    def test_register_non_prism_raises(self):
        reg = PrismRegistry()
        with self.assertRaises(PrismError):
            reg.register(object())

    def test_len_and_contains(self):
        reg = PrismRegistry()
        reg.register(_AdderPrism())
        self.assertEqual(len(reg), 1)
        self.assertIn("adder", reg)
        self.assertEqual(reg.names(), ["adder"])


# --------------------------------------------------------------------------- #
# build_registry factory
# --------------------------------------------------------------------------- #

class BuildRegistryTests(unittest.TestCase):
    def test_registry_preloaded_with_all_prisms(self):
        reg = build_registry()
        expected = {
            "channel_stats", "channel_resource", "search_result", "channel_list",
            "video_stats", "video_resource", "video_list",
            "playlist_resource", "playlist_items", "uploads",
            "engagement", "engagement_compare", "keywords", "channel_keywords",
        }
        self.assertEqual(set(reg.names()), expected)

    def test_dispatch_through_registry(self):
        reg = build_registry()
        res = reg.run("video_stats", {"resource": VIDEO_RESOURCE})
        self.assertEqual(res.unwrap()["view_count"], 150000)


# --------------------------------------------------------------------------- #
# Channel prisms
# --------------------------------------------------------------------------- #

class ChannelPrismTests(unittest.TestCase):
    def test_channel_stats_parses_counts(self):
        res = ChannelStatsPrism()({"resource": CHANNEL_RESOURCE}).unwrap()
        self.assertEqual(res["subscriber_count"], 2350000)
        self.assertEqual(res["view_count"], 284741235)
        self.assertEqual(res["video_count"], 6234)
        self.assertFalse(res["hidden_subscriber_count"])
        # avg views per video = 284741235 / 6234 = 45675.53...
        self.assertAlmostEqual(res["avg_views_per_video"], 45675.53, places=2)

    def test_channel_resource_summary(self):
        res = ChannelResourcePrism()({"resource": CHANNEL_RESOURCE}).unwrap()
        self.assertEqual(res["id"], "UC_x5XG1OV2P6uZZ5FSM9Ttw")
        self.assertEqual(res["uploads_playlist_id"], "UU_x5XG1OV2P6uZZ5FSM9Ttw")
        self.assertEqual(res["custom_url"], "@googledevelopers")

    def test_search_result_video(self):
        res = SearchResultPrism()({"item": SEARCH_VIDEO_ITEM}).unwrap()
        self.assertEqual(res["kind"], "video")
        self.assertEqual(res["id"], "abc123")
        self.assertEqual(res["title"], "Intro to Kubernetes")

    def test_search_result_channel(self):
        res = SearchResultPrism()({"item": SEARCH_CHANNEL_ITEM}).unwrap()
        self.assertEqual(res["kind"], "channel")
        self.assertEqual(res["id"], "UCxyz")

    def test_channel_list_aggregates(self):
        res = ChannelListPrism()(
            {"resources": [CHANNEL_RESOURCE, CHANNEL_RESOURCE]}
        ).unwrap()
        self.assertEqual(res["count"], 2)
        self.assertEqual(len(res["channels"]), 2)


# --------------------------------------------------------------------------- #
# Video prisms
# --------------------------------------------------------------------------- #

class VideoPrismTests(unittest.TestCase):
    def test_video_stats_ratios(self):
        res = VideoStatsPrism()({"resource": VIDEO_RESOURCE}).unwrap()
        self.assertEqual(res["view_count"], 150000)
        self.assertEqual(res["like_count"], 9000)
        self.assertEqual(res["comment_count"], 600)
        # like_ratio = 9000/150000 = 0.06
        self.assertAlmostEqual(res["like_ratio"], 0.06, places=4)

    def test_video_resource_duration_parse(self):
        res = VideoResourcePrism()({"resource": VIDEO_RESOURCE}).unwrap()
        self.assertEqual(res["duration"], "PT1H2M3S")
        self.assertEqual(res["duration_seconds"], 3723)  # 3600 + 120 + 3
        self.assertEqual(res["category_id"], "28")
        self.assertEqual(res["tags"], ["cloud", "web", "tutorial"])

    def test_iso8601_duration_variants(self):
        self.assertEqual(_iso8601_to_seconds("PT30S"), 30)
        self.assertEqual(_iso8601_to_seconds("PT5M"), 300)
        self.assertEqual(_iso8601_to_seconds("PT2H"), 7200)
        self.assertEqual(_iso8601_to_seconds("P1D"), 0)  # days unsupported -> 0
        self.assertEqual(_iso8601_to_seconds("not-a-duration"), 0)

    def test_video_list_totals(self):
        res = VideoListPrism()(
            {"resources": [VIDEO_RESOURCE, VIDEO_RESOURCE]}
        ).unwrap()
        self.assertEqual(res["count"], 2)
        self.assertEqual(res["total_views"], 300000)
        self.assertEqual(res["total_likes"], 18000)
        self.assertEqual(res["total_comments"], 1200)


# --------------------------------------------------------------------------- #
# Playlist prisms
# --------------------------------------------------------------------------- #

class PlaylistPrismTests(unittest.TestCase):
    def test_playlist_resource(self):
        res = PlaylistResourcePrism()({"resource": PLAYLIST_RESOURCE}).unwrap()
        self.assertEqual(res["id"], "PL123")
        self.assertEqual(res["item_count"], 42)

    def test_playlist_items_normalised(self):
        res = PlaylistItemsPrism()(
            {"items": PLAYLIST_ITEMS_RESPONSE["items"]}
        ).unwrap()
        self.assertEqual(res["count"], 2)
        self.assertEqual(res["entries"][0]["video_id"], "vid001")
        self.assertEqual(res["entries"][1]["position"], 1)

    def test_uploads_digest(self):
        res = UploadsPrism()({
            "uploads_playlist_id": "UU_x5XG1OV2P6uZZ5FSM9Ttw",
            "items": PLAYLIST_ITEMS_RESPONSE["items"],
        }).unwrap()
        self.assertEqual(res["count"], 2)
        self.assertEqual(res["video_ids"], ["vid001", "vid002"])
        self.assertEqual(res["titles"][0], "Intro to Cloud Run")


# --------------------------------------------------------------------------- #
# Engagement prisms
# --------------------------------------------------------------------------- #

class EngagementPrismTests(unittest.TestCase):
    def test_engagement_rate(self):
        res = EngagementPrism()({
            "video_id": "dQw4w9WgXcQ",
            "stats": {
                "view_count": 150000,
                "like_count": 9000,
                "comment_count": 600,
            },
        }).unwrap()
        # (9000 + 600) / 150000 * 100 = 6.4
        self.assertAlmostEqual(res["engagement_rate_percent"], 6.4, places=2)

    def test_engagement_zero_views_safe(self):
        res = EngagementPrism()({
            "stats": {"view_count": 0, "like_count": 0, "comment_count": 0}
        }).unwrap()
        self.assertEqual(res["engagement_rate_percent"], 0.0)

    def test_engagement_compare_ranks(self):
        res = EngagementComparePrism()({"videos": [
            {"video_id": "a", "view_count": 1000, "like_count": 100, "comment_count": 0},
            {"video_id": "b", "view_count": 1000, "like_count": 10, "comment_count": 0},
        ]}).unwrap()
        self.assertEqual(res["count"], 2)
        self.assertEqual(res["top"]["video_id"], "a")  # 10% > 1%
        self.assertAlmostEqual(res["average_engagement_rate_percent"], 5.5, places=2)


# --------------------------------------------------------------------------- #
# Keyword prisms
# --------------------------------------------------------------------------- #

class KeywordPrismTests(unittest.TestCase):
    def test_keyword_extraction_filters_stopwords(self):
        res = KeywordPrism()(
            {"text": "Build a web app with Google Cloud Run", "limit": 10}
        ).unwrap()
        kws = res["keywords"]
        self.assertIn("build", kws)
        self.assertIn("cloud", kws)
        self.assertNotIn("with", kws)  # stopword
        self.assertNotIn("the", kws)   # stopword

    def test_channel_keywords_frequency(self):
        res = ChannelKeywordsPrism()({"titles": [
            "Cloud Run tutorial",
            "Cloud Functions tutorial",
            "Cloud Run deep dive",
        ]}).unwrap()
        top = res["top_keywords"]
        # 'cloud' appears 3x -> rank 0
        self.assertEqual(top[0]["keyword"], "cloud")
        self.assertEqual(top[0]["count"], 3)
        # 'run' and 'tutorial' both appear 2x; tie broken alphabetically
        # ('run' < 'tutorial'), so rank 1 is 'run'.
        self.assertEqual(top[1]["keyword"], "run")
        self.assertEqual(top[1]["count"], 2)
        # both 2-count keywords must be present in the ranking
        counts = {e["keyword"]: e["count"] for e in top}
        self.assertEqual(counts["tutorial"], 2)


# --------------------------------------------------------------------------- #
# util helpers (pure transforms)
# --------------------------------------------------------------------------- #

class UtilTests(unittest.TestCase):
    def test_to_int_coercion(self):
        self.assertEqual(to_int("42"), 42)
        self.assertEqual(to_int(42), 42)
        self.assertEqual(to_int(3.9), 3)
        self.assertEqual(to_int(None), 0)
        self.assertEqual(to_int("nope"), 0)
        self.assertEqual(to_int(-5), 0)  # negatives clamp to 0

    def test_to_float_coercion(self):
        self.assertEqual(to_float("3.5"), 3.5)
        self.assertEqual(to_float(2), 2.0)
        self.assertEqual(to_float("bad"), 0.0)

    def test_safe_div(self):
        self.assertEqual(safe_div(10, 2), 5.0)
        self.assertEqual(safe_div(10, 0), 0.0)

    def test_percent(self):
        self.assertAlmostEqual(percent(9600, 150000), 6.4, places=2)
        self.assertEqual(percent(1, 0), 0.0)

    def test_round_to(self):
        self.assertEqual(round_to(1.23456, 2), 1.23)

    def test_tokenize_and_keywords(self):
        self.assertEqual(tokenize("Hello WORLD a bb ccc"), ["hello", "world", "ccc"])
        kws = keywords("the quick brown fox jumps", limit=3)
        self.assertEqual(kws, ["quick", "brown", "fox"])

    def test_top_frequency(self):
        ranked = top_frequency(["a", "b", "a", "c", "a", "b"], limit=2)
        self.assertEqual(ranked[0], ("a", 3))
        self.assertEqual(ranked[1], ("b", 2))


# --------------------------------------------------------------------------- #
# youtube_client integration layer — pure helpers (no network)
# --------------------------------------------------------------------------- #

class YouTubeClientHelperTests(unittest.TestCase):
    def test_client_requires_api_key(self):
        old = os.environ.pop("YOUTUBE_API_KEY", None)
        try:
            with self.assertRaises(youtube_client.YouTubeAPIError):
                youtube_client.YouTubeClient()
        finally:
            if old is not None:
                os.environ["YOUTUBE_API_KEY"] = old

    def test_client_accepts_explicit_key(self):
        c = youtube_client.YouTubeClient(api_key="DUMMY_KEY")
        self.assertEqual(c.api_key, "DUMMY_KEY")
        self.assertEqual(c.api_base, "https://www.googleapis.com/youtube/v3")

    def test_extract_keywords_from_title(self):
        c = youtube_client.YouTubeClient(api_key="DUMMY_KEY")
        kws = c.extract_keywords_from_title(
            "How to build a web app with Google Cloud Run"
        )
        self.assertIn("build", kws)
        self.assertIn("cloud", kws)
        self.assertNotIn("with", kws)
        self.assertLessEqual(len(kws), 10)

    def test_extract_keywords_dedups(self):
        c = youtube_client.YouTubeClient(api_key="DUMMY_KEY")
        kws = c.extract_keywords_from_title("cloud cloud cloud run")
        self.assertEqual(kws.count("cloud"), 1)

    def test_analyze_video_engagement_parses_stats(self):
        c = youtube_client.YouTubeClient(api_key="DUMMY_KEY")
        # Monkeypatch get_video to avoid network; exercise pure aggregation.
        c.get_video = lambda vid, parts=None: {
            "snippet": {"title": "T", "channelTitle": "C", "publishedAt": "2024"},
            "statistics": {
                "viewCount": "1000",
                "likeCount": "100",
                "commentCount": "50",
            },
        }
        res = c.analyze_video_engagement("vid1")
        self.assertEqual(res["view_count"], 1000)
        self.assertEqual(res["like_count"], 100)
        # (100 + 50) / 1000 * 100 = 15.0
        self.assertAlmostEqual(res["engagement_rate_percent"], 15.0, places=2)

    def test_analyze_video_engagement_zero_views(self):
        c = youtube_client.YouTubeClient(api_key="DUMMY_KEY")
        c.get_video = lambda vid, parts=None: {
            "snippet": {},
            "statistics": {"viewCount": "0"},
        }
        res = c.analyze_video_engagement("vid0")
        self.assertEqual(res["engagement_rate_percent"], 0.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)