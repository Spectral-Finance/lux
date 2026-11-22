#!/usr/bin/env python3
"""
test_youtube.py — stdlib-only test suite for youtube_client.py (Lux issue #69).

Exercises the real, network-free logic of the YouTube Data API v3 client by
patching ``urllib.request.urlopen`` so the *actual* ``_request`` method runs
(including API-key injection and URL/query encoding). No sockets are opened.

Coverage:
  * Client construction & API-key handling
  * Query-parameter building (search, videos, channels, playlistItems)
  * Response parsing (video details, channel details, statistics)
  * Content-intelligence scoring (engagement rate, keyword extraction,
    channel content analysis)

Runs under pytest OR as a plain script (stdlib fallback runner at the bottom).
"""

import io
import json
import os
import sys
import unittest
import urllib.parse

# Make ``youtube_client`` importable regardless of CWD. The module lives at
# ``youtube_client/youtube_client.py`` inside this packet, so we add that
# subdirectory (not the packet root, which would shadow the module with the
# same-named namespace-package directory).
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "youtube_client"))

import youtube_client as yc  # noqa: E402


# --------------------------------------------------------------------------- #
# Fake urlopen — intercepts HTTP so the REAL _request() runs (no network).
# --------------------------------------------------------------------------- #
class FakeResponse(io.BytesIO):
    """Minimal stand-in for http.client.HTTPResponse (context-manager + read)."""

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False


class UrlopenSpy:
    """Drop-in replacement for urllib.request.urlopen.

    Records every Request URL, resolves a canned payload by endpoint, and
    returns a FakeResponse. Payloads may be callables that receive the parsed
    query-param dict (useful for id-specific responses).
    """

    def __init__(self, payloads=None):
        self.payloads = payloads or {}
        self.urls = []

    def __call__(self, req, timeout=None):
        url = req.full_url
        self.urls.append(url)
        parsed = urllib.parse.urlparse(url)
        # Path is /youtube/v3/<endpoint>
        endpoint = parsed.path.rsplit("/", 1)[-1]
        params = dict(urllib.parse.parse_qsl(parsed.query))

        payload = self.payloads.get(endpoint, self.payloads.get("/" + endpoint))
        if payload is None:
            payload = {}
        if callable(payload):
            payload = payload(params)
        return FakeResponse(json.dumps(payload).encode("utf-8"))


def make_client(payloads=None, api_key="TEST_KEY"):
    """Build a YouTubeClient whose urlopen is intercepted (no network)."""
    client = yc.YouTubeClient(api_key=api_key)
    spy = UrlopenSpy(payloads)
    # Patch the symbol as referenced inside the youtube_client module.
    yc.urllib.request.urlopen = spy
    client._spy = spy
    return client


def last_params(client):
    """Parse the query params of the most recent intercepted request."""
    url = client._spy.urls[-1]
    return dict(urllib.parse.parse_qsl(urllib.parse.urlparse(url).query))


# --------------------------------------------------------------------------- #
# 1. Client construction & API-key handling
# --------------------------------------------------------------------------- #
class TestClientConstruction(unittest.TestCase):
    def tearDown(self):
        # Restore urlopen after each test to avoid cross-test leakage.
        import urllib.request
        urllib.request.urlopen = _REAL_URLOPEN

    def test_init_with_explicit_key(self):
        client = yc.YouTubeClient(api_key="MY_KEY")
        self.assertEqual(client.api_key, "MY_KEY")
        self.assertEqual(client.api_base, "https://www.googleapis.com/youtube/v3")

    def test_init_with_env_key(self):
        os.environ["YOUTUBE_API_KEY"] = "ENV_KEY"
        try:
            client = yc.YouTubeClient()
            self.assertEqual(client.api_key, "ENV_KEY")
        finally:
            del os.environ["YOUTUBE_API_KEY"]

    def test_init_without_key_raises(self):
        old = os.environ.pop("YOUTUBE_API_KEY", None)
        try:
            with self.assertRaises(yc.YouTubeAPIError):
                yc.YouTubeClient()
        finally:
            if old is not None:
                os.environ["YOUTUBE_API_KEY"] = old

    def test_api_error_is_exception(self):
        self.assertTrue(issubclass(yc.YouTubeAPIError, Exception))


# --------------------------------------------------------------------------- #
# 2. Query-parameter building (verified against the REAL _request URL)
# --------------------------------------------------------------------------- #
class TestQueryBuilding(unittest.TestCase):
    def tearDown(self):
        import urllib.request
        urllib.request.urlopen = _REAL_URLOPEN

    def test_get_video_params(self):
        client = make_client({"videos": {"items": []}})
        client.get_video("dQw4w9WgXcQ")
        params = last_params(client)
        self.assertEqual(params["id"], "dQw4w9WgXcQ")
        self.assertEqual(params["part"], "snippet,statistics,contentDetails")
        # The real _request injects the API key.
        self.assertEqual(params["key"], "TEST_KEY")

    def test_get_video_custom_parts(self):
        client = make_client({"videos": {"items": []}})
        client.get_video("vid1", parts=["snippet", "statistics"])
        params = last_params(client)
        self.assertEqual(params["part"], "snippet,statistics")

    def test_search_videos_params(self):
        client = make_client({"search": {"items": []}})
        client.search_videos("python tutorial", max_results=10, order="viewCount")
        params = last_params(client)
        self.assertEqual(params["q"], "python tutorial")
        self.assertEqual(params["part"], "snippet")
        self.assertEqual(params["maxResults"], "10")
        self.assertEqual(params["order"], "viewCount")
        self.assertEqual(params["type"], "video")
        self.assertEqual(params["key"], "TEST_KEY")

    def test_search_videos_with_published_after(self):
        client = make_client({"search": {"items": []}})
        client.search_videos("cats", published_after="2023-01-01T00:00:00Z")
        params = last_params(client)
        self.assertEqual(params["publishedAfter"], "2023-01-01T00:00:00Z")

    def test_search_videos_default_params(self):
        client = make_client({"search": {"items": []}})
        client.search_videos("test")
        params = last_params(client)
        self.assertEqual(params["maxResults"], "25")
        self.assertEqual(params["order"], "relevance")
        self.assertEqual(params["type"], "video")

    def test_get_channel_params(self):
        client = make_client({"channels": {"items": []}})
        client.get_channel("UC123")
        params = last_params(client)
        self.assertEqual(params["id"], "UC123")
        self.assertEqual(params["part"], "snippet,statistics,contentDetails")

    def test_get_channel_by_username_params(self):
        client = make_client({"channels": {"items": []}})
        client.get_channel_by_username("someuser")
        params = last_params(client)
        self.assertEqual(params["forUsername"], "someuser")

    def test_get_channel_uploads_params(self):
        payloads = {
            "channels": {
                "items": [
                    {"contentDetails": {"relatedPlaylists": {"uploads": "UU123"}}}
                ]
            },
            "playlistItems": {"items": []},
        }
        client = make_client(payloads)
        client.get_channel_uploads("UC123", max_results=10)
        # Second intercepted request should be playlistItems.
        params = last_params(client)
        self.assertEqual(params["playlistId"], "UU123")
        self.assertEqual(params["maxResults"], "10")

    def test_get_channel_uploads_no_playlist(self):
        client = make_client({"channels": {"items": [{}]}})
        result = client.get_channel_uploads("UC123")
        self.assertEqual(result, [])


# --------------------------------------------------------------------------- #
# 3. Response parsing
# --------------------------------------------------------------------------- #
class TestResponseParsing(unittest.TestCase):
    def tearDown(self):
        import urllib.request
        urllib.request.urlopen = _REAL_URLOPEN

    def test_get_video_returns_first_item(self):
        payload = {
            "items": [
                {
                    "id": "vid1",
                    "snippet": {"title": "Test Video", "channelId": "UC1"},
                    "statistics": {"viewCount": "1000", "likeCount": "50"},
                }
            ]
        }
        client = make_client({"videos": payload})
        video = client.get_video("vid1")
        self.assertEqual(video["id"], "vid1")
        self.assertEqual(video["snippet"]["title"], "Test Video")
        self.assertEqual(video["statistics"]["viewCount"], "1000")

    def test_get_video_empty_items(self):
        client = make_client({"videos": {"items": []}})
        video = client.get_video("missing")
        self.assertEqual(video, {})

    def test_get_video_statistics(self):
        payload = {
            "items": [
                {
                    "id": "vid1",
                    "statistics": {"viewCount": "5000", "likeCount": "200", "commentCount": "50"},
                }
            ]
        }
        client = make_client({"videos": payload})
        stats = client.get_video_statistics("vid1")
        self.assertEqual(stats["viewCount"], "5000")
        self.assertEqual(stats["likeCount"], "200")
        self.assertEqual(stats["commentCount"], "50")

    def test_search_videos_returns_items(self):
        payload = {
            "items": [
                {"id": {"videoId": "s1"}, "snippet": {"title": "Result 1"}},
                {"id": {"videoId": "s2"}, "snippet": {"title": "Result 2"}},
            ]
        }
        client = make_client({"search": payload})
        results = client.search_videos("query")
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]["id"]["videoId"], "s1")

    def test_get_channel_returns_first_item(self):
        payload = {
            "items": [
                {
                    "id": "UC1",
                    "snippet": {"title": "Test Channel"},
                    "statistics": {"subscriberCount": "1000", "videoCount": "50"},
                }
            ]
        }
        client = make_client({"channels": payload})
        channel = client.get_channel("UC1")
        self.assertEqual(channel["id"], "UC1")
        self.assertEqual(channel["snippet"]["title"], "Test Channel")
        self.assertEqual(channel["statistics"]["subscriberCount"], "1000")

    def test_get_channel_statistics(self):
        payload = {
            "items": [
                {
                    "id": "UC1",
                    "statistics": {
                        "subscriberCount": "2000",
                        "viewCount": "100000",
                        "videoCount": "75",
                    },
                }
            ]
        }
        client = make_client({"channels": payload})
        stats = client.get_channel_statistics("UC1")
        self.assertEqual(stats["subscriberCount"], "2000")
        self.assertEqual(stats["viewCount"], "100000")
        self.assertEqual(stats["videoCount"], "75")


# --------------------------------------------------------------------------- #
# 4. Content-intelligence scoring
# --------------------------------------------------------------------------- #
class TestContentIntelligence(unittest.TestCase):
    def tearDown(self):
        import urllib.request
        urllib.request.urlopen = _REAL_URLOPEN

    def test_analyze_video_engagement(self):
        payload = {
            "items": [
                {
                    "id": "vid1",
                    "snippet": {
                        "title": "How to Bake Bread",
                        "channelTitle": "Cooking Channel",
                        "publishedAt": "2023-01-01T00:00:00Z",
                    },
                    "statistics": {
                        "viewCount": "10000",
                        "likeCount": "500",
                        "commentCount": "100",
                    },
                }
            ]
        }
        client = make_client({"videos": payload})
        result = client.analyze_video_engagement("vid1")
        self.assertEqual(result["video_id"], "vid1")
        self.assertEqual(result["title"], "How to Bake Bread")
        self.assertEqual(result["channel_title"], "Cooking Channel")
        self.assertEqual(result["view_count"], 10000)
        self.assertEqual(result["like_count"], 500)
        self.assertEqual(result["comment_count"], 100)
        # engagement_rate = (500 + 100) / 10000 * 100 = 6.0
        self.assertEqual(result["engagement_rate_percent"], 6.0)

    def test_analyze_video_engagement_zero_views(self):
        payload = {
            "items": [
                {
                    "id": "vid1",
                    "snippet": {
                        "title": "T",
                        "channelTitle": "C",
                        "publishedAt": "2023-01-01T00:00:00Z",
                    },
                    "statistics": {"viewCount": "0", "likeCount": "0", "commentCount": "0"},
                }
            ]
        }
        client = make_client({"videos": payload})
        result = client.analyze_video_engagement("vid1")
        self.assertEqual(result["engagement_rate_percent"], 0.0)

    def test_extract_keywords_from_title(self):
        client = make_client()
        keywords = client.extract_keywords_from_title("How to Bake Artisan Bread at Home")
        self.assertIsInstance(keywords, list)
        self.assertIn("bake", keywords)
        self.assertIn("artisan", keywords)
        self.assertIn("bread", keywords)
        self.assertNotIn("how", keywords)   # stop word
        self.assertNotIn("the", keywords)   # stop word
        self.assertNotIn("at", keywords)    # too short (< 3 chars)

    def test_extract_keywords_deduplicates(self):
        client = make_client()
        keywords = client.extract_keywords_from_title("Python Python Python Tutorial")
        self.assertEqual(keywords.count("python"), 1)

    def test_extract_keywords_limits_to_10(self):
        client = make_client()
        title = " ".join(f"word{i}" for i in range(20))
        keywords = client.extract_keywords_from_title(title)
        self.assertLessEqual(len(keywords), 10)

    def test_extract_keywords_empty_title(self):
        client = make_client()
        keywords = client.extract_keywords_from_title("")
        self.assertEqual(keywords, [])

    def test_analyze_channel_content(self):
        channel_payload = {
            "items": [
                {
                    "id": "UC1",
                    "snippet": {"title": "Test Channel"},
                    "statistics": {
                        "subscriberCount": "5000",
                        "viewCount": "500000",
                        "videoCount": "100",
                    },
                    "contentDetails": {"relatedPlaylists": {"uploads": "UU1"}},
                }
            ]
        }
        uploads_payload = {
            "items": [
                {"snippet": {"title": "Python Tutorial", "resourceId": {"videoId": "v1"}}},
                {"snippet": {"title": "Python Advanced", "resourceId": {"videoId": "v2"}}},
            ]
        }

        # ID-aware videos payload: return stats matching the requested id.
        def videos_payload(params):
            vid = params.get("id")
            table = {
                "v1": {"viewCount": "1000", "likeCount": "50", "commentCount": "10"},
                "v2": {"viewCount": "2000", "likeCount": "100", "commentCount": "20"},
            }
            stats = table.get(vid, {})
            return {"items": [{"id": vid, "statistics": stats}]}

        payloads = {
            "channels": channel_payload,
            "playlistItems": uploads_payload,
            "videos": videos_payload,
        }
        client = make_client(payloads)
        result = client.analyze_channel_content("UC1")
        self.assertEqual(result["channel_id"], "UC1")
        self.assertEqual(result["channel_title"], "Test Channel")
        self.assertEqual(result["subscriber_count"], 5000)
        self.assertEqual(result["view_count"], 500000)
        self.assertEqual(result["video_count"], 100)
        self.assertEqual(result["recent_uploads_analyzed"], 2)
        self.assertEqual(result["total_recent_views"], 3000)
        self.assertEqual(result["total_recent_likes"], 150)
        self.assertEqual(result["total_recent_comments"], 30)
        self.assertIsInstance(result["top_keywords"], list)
        # "python" appears in both titles -> top keyword with count 2.
        if result["top_keywords"]:
            self.assertEqual(result["top_keywords"][0][0], "python")
            self.assertEqual(result["top_keywords"][0][1], 2)


# --------------------------------------------------------------------------- #
# 5. End-to-end client flow with intercepted urlopen (no network)
# --------------------------------------------------------------------------- #
class TestClientFlow(unittest.TestCase):
    def tearDown(self):
        import urllib.request
        urllib.request.urlopen = _REAL_URLOPEN

    def test_get_video_flow(self):
        payload = {
            "items": [
                {
                    "id": "vid1",
                    "snippet": {
                        "title": "T",
                        "channelId": "c",
                        "publishedAt": "2023-01-01T00:00:00Z",
                    },
                    "statistics": {"viewCount": "10", "likeCount": "1", "commentCount": "0"},
                }
            ]
        }
        client = make_client({"videos": payload})
        video = client.get_video("vid1")
        self.assertEqual(video["id"], "vid1")
        self.assertEqual(video["statistics"]["viewCount"], "10")
        # Verify the real request hit the videos endpoint.
        self.assertIn("/videos?", client._spy.urls[0])

    def test_search_flow(self):
        payload = {
            "items": [
                {"id": {"videoId": "s1"}, "snippet": {"title": "Result 1"}},
                {"id": {"videoId": "s2"}, "snippet": {"title": "Result 2"}},
            ]
        }
        client = make_client({"search": payload})
        results = client.search_videos("query")
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]["id"]["videoId"], "s1")

    def test_get_channel_flow(self):
        payload = {
            "items": [
                {
                    "id": "UC1",
                    "snippet": {"title": "Chan", "publishedAt": "2010-01-01T00:00:00Z"},
                    "statistics": {
                        "subscriberCount": "5",
                        "videoCount": "2",
                        "viewCount": "100",
                    },
                }
            ]
        }
        client = make_client({"channels": payload})
        channel = client.get_channel("UC1")
        self.assertEqual(channel["id"], "UC1")
        self.assertEqual(channel["statistics"]["subscriberCount"], "5")

    def test_get_video_not_found_returns_empty(self):
        client = make_client({"videos": {"items": []}})
        video = client.get_video("missing")
        self.assertEqual(video, {})

    def test_multiple_requests_tracked(self):
        payloads = {
            "videos": {"items": [{"id": "v1", "statistics": {}}]},
            "channels": {"items": [{"id": "c1", "statistics": {}}]},
        }
        client = make_client(payloads)
        client.get_video("v1")
        client.get_channel("c1")
        self.assertEqual(len(client._spy.urls), 2)
        self.assertIn("/videos?", client._spy.urls[0])
        self.assertIn("/channels?", client._spy.urls[1])


# --------------------------------------------------------------------------- #
# stdlib fallback runner (works without pytest)
# --------------------------------------------------------------------------- #
_REAL_URLOPEN = urllib.request.urlopen


def _run_stdlib():
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    total = result.testsRun
    failures = len(result.failures)
    errors = len(result.errors)
    passed = total - failures - errors
    print("\n" + "=" * 60)
    print(f"RESULT: {passed} passed, {failures} failed, {errors} errors, {total} total")
    print("=" * 60)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(_run_stdlib())