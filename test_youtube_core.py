"""Offline test suite for the YouTube Core Integration + Live Streaming suite.

Every test runs fully offline: a :class:`FakeTransport` stands in for the
network and no live YouTube credentials are ever required. The suite covers
OAuth2 flows, resource clients (channels/videos/playlists), the live-stream
and broadcast lifecycle, live chat, stream-health monitoring, rate limiting,
retries, and error mapping.
"""

import json
import urllib.parse
import urllib.error
import urllib.request

import pytest

import youtube_core as yt
from youtube_core import (
    AuthenticationError,
    BadRequestError,
    BroadcastTransition,
    Channel,
    ForbiddenError,
    LiveBroadcast,
    LiveChatMessage,
    LiveStream,
    NotFoundError,
    OAuth2,
    OAuth2Config,
    Playlist,
    PlaylistItem,
    QuotaExceededError,
    RateLimiter,
    RetryPolicy,
    StreamHealth,
    TokenSet,
    Video,
    YouTubeAPIError,
    YouTubeClient,
    YouTubeCore,
    YouTubeError,
    YouTubeResponse,
)


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------
class FakeTransport:
    """A scriptable transport that records requests and replays responses.

    ``responses`` is a list of items; each item may be:
      * a ``(status, body_dict)`` tuple,
      * a ``(status, body_dict, headers)`` tuple,
      * an ``Exception`` instance to raise (e.g. ``urllib.error.URLError``).

    When the list is exhausted the last response is repeated.
    """

    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []
        self._index = 0

    def send(self, request):
        self.requests.append(request)
        if not self.responses:
            raise AssertionError("FakeTransport has no configured responses")
        item = self.responses[min(self._index, len(self.responses) - 1)]
        self._index += 1
        if isinstance(item, Exception):
            raise item
        if len(item) == 2:
            status, body = item
            headers = {}
        else:
            status, body, headers = item
        raw = b"" if body is None else json.dumps(body).encode("utf-8")
        return status, headers, raw

    # -- introspection helpers ------------------------------------------
    def last_request(self):
        return self.requests[-1]

    def bodies(self):
        """Decode request bodies, handling both JSON and form-encoded payloads."""
        out = []
        for req in self.requests:
            data = req.data
            if not data:
                out.append(None)
                continue
            text = data.decode("utf-8")
            try:
                out.append(json.loads(text))
            except (ValueError, json.JSONDecodeError):
                parsed = urllib.parse.parse_qs(text)
                out.append({k: (v[0] if len(v) == 1 else v) for k, v in parsed.items()})
        return out


def make_oauth(transport, access_token="test-access-token", **store):
    """Build an OAuth2 instance preloaded with a valid token."""
    store.setdefault("access_token", access_token)
    store.setdefault("refresh_token", "test-refresh-token")
    store.setdefault("expires_in", 3600)
    config = OAuth2Config(client_id="cid", client_secret="secret")
    return OAuth2(config, transport=transport, token_store=dict(store))


def make_client(transport, **kwargs):
    oauth = make_oauth(transport)
    kwargs.setdefault("retry_policy", RetryPolicy(sleep_func=lambda _: None))
    return YouTubeClient(oauth=oauth, transport=transport, **kwargs)


# ---------------------------------------------------------------------------
# OAuth2 / token management
# ---------------------------------------------------------------------------
class TestOAuth2:
    def test_authorization_url_contains_scopes_and_client(self):
        config = OAuth2Config(
            client_id="my-client",
            client_secret="s",
            scopes=(yt.SCOPE_READONLY, yt.SCOPE_LIVE),
        )
        oauth = OAuth2(config, transport=FakeTransport([]))
        url = oauth.authorization_url(state="xyz")
        assert url.startswith(yt.AUTHORIZE_URL)
        assert "client_id=my-client" in url
        assert "response_type=code" in url
        assert "state=xyz" in url
        assert "youtube.readonly" in url
        assert "access_type=offline" in url

    def test_exchange_code_persists_token(self):
        transport = FakeTransport(
            [
                (
                    200,
                    {
                        "access_token": "AT-1",
                        "refresh_token": "RT-1",
                        "expires_in": 3600,
                        "token_type": "Bearer",
                    },
                )
            ]
        )
        config = OAuth2Config(client_id="cid", client_secret="secret")
        store = {}
        oauth = OAuth2(config, transport=transport, token_store=store)
        token = oauth.exchange_code("auth-code-123")
        assert token.access_token == "AT-1"
        assert token.refresh_token == "RT-1"
        # Token store should be updated for persistence across runs.
        assert store["access_token"] == "AT-1"
        assert store["refresh_token"] == "RT-1"
        # Verify the request hit the token endpoint with the right grant.
        body = transport.bodies()[0]
        assert body["grant_type"] == "authorization_code"
        assert body["code"] == "auth-code-123"

    def test_refresh_preserves_refresh_token_when_omitted(self):
        transport = FakeTransport(
            [(200, {"access_token": "AT-2", "expires_in": 3600})]
        )
        config = OAuth2Config(client_id="cid", client_secret="secret")
        oauth = OAuth2(
            config,
            transport=transport,
            token_store={"access_token": "old", "refresh_token": "RT-keep"},
        )
        token = oauth.refresh()
        assert token.access_token == "AT-2"
        # YouTube omits refresh_token on refresh; we must preserve the old one.
        assert token.refresh_token == "RT-keep"

    def test_refresh_without_token_raises(self):
        oauth = OAuth2(
            OAuth2Config(client_id="cid", client_secret="s"),
            transport=FakeTransport([]),
        )
        with pytest.raises(AuthenticationError) as exc:
            oauth.refresh()
        assert exc.value.reason == "noRefreshToken"

    def test_get_access_token_refreshes_when_expired(self):
        transport = FakeTransport(
            [(200, {"access_token": "AT-fresh", "expires_in": 3600})]
        )
        config = OAuth2Config(client_id="cid", client_secret="secret")
        # issued_at far in the past -> expired.
        oauth = OAuth2(
            config,
            transport=transport,
            token_store={
                "access_token": "AT-old",
                "refresh_token": "RT-1",
                "issued_at": 0.0,
            },
        )
        token = oauth.get_access_token()
        assert token == "AT-fresh"

    def test_get_access_token_without_token_raises(self):
        oauth = OAuth2(
            OAuth2Config(client_id="cid", client_secret="s"),
            transport=FakeTransport([]),
        )
        with pytest.raises(AuthenticationError) as exc:
            oauth.get_access_token()
        assert exc.value.status == 401

    def test_token_set_expiry_logic(self):
        tok = TokenSet(access_token="a", expires_in=100, issued_at=1000.0)
        assert tok.expires_at == 1100.0
        # With the default 60s leeway the token is considered expired at 1040.
        assert tok.is_expired(now=1030.0) is False
        assert tok.is_expired(now=1050.0) is True  # within 60s leeway
        assert tok.is_expired(leeway=0, now=1099.0) is False
        assert tok.is_expired(leeway=0, now=1100.0) is True

    def test_device_code_flow_polls_until_success(self):
        transport = FakeTransport(
            [
                # token endpoint: pending, then success
                (400, {"error": "authorization_pending"}),
                (
                    200,
                    {"access_token": "AT-dev", "refresh_token": "RT-dev", "expires_in": 3600},
                ),
            ]
        )
        config = OAuth2Config(client_id="cid", client_secret="s")
        oauth = OAuth2(config, transport=transport)
        token = oauth.poll_device_token("dev-code", interval=0)
        assert token.access_token == "AT-dev"

    def test_device_code_request(self):
        transport = FakeTransport(
            [
                (
                    200,
                    {
                        "device_code": "dc",
                        "user_code": "uc",
                        "verification_url": "https://example/verify",
                        "interval": 5,
                    },
                )
            ]
        )
        config = OAuth2Config(client_id="cid", client_secret="s")
        oauth = OAuth2(config, transport=transport)
        info = oauth.request_device_code()
        assert info["device_code"] == "dc"
        assert info["verification_url"] == "https://example/verify"


# ---------------------------------------------------------------------------
# Rate limiter + retry policy
# ---------------------------------------------------------------------------
class TestRateLimiter:
    def test_acquire_up_to_limit(self):
        clock = {"t": 0.0}
        rl = RateLimiter(max_calls=3, period=10.0, time_func=lambda: clock["t"])
        assert rl.try_acquire() is True
        assert rl.try_acquire() is True
        assert rl.try_acquire() is True
        assert rl.try_acquire() is False  # over the limit
        assert rl.remaining() == 0

    def test_window_slides(self):
        clock = {"t": 0.0}
        rl = RateLimiter(max_calls=2, period=10.0, time_func=lambda: clock["t"])
        rl.try_acquire()
        rl.try_acquire()
        assert rl.try_acquire() is False
        clock["t"] = 11.0  # advance beyond the window
        assert rl.try_acquire() is True

    def test_acquire_blocks_until_slot_free(self):
        sleeps = []
        clock = {"t": 0.0}

        def fake_sleep(seconds):
            sleeps.append(seconds)
            clock["t"] += seconds

        rl = RateLimiter(max_calls=1, period=5.0, time_func=lambda: clock["t"])
        rl._clock = lambda: clock["t"]
        # Patch time.sleep used inside acquire.
        import youtube_core

        orig = youtube_core.time.sleep
        youtube_core.time.sleep = fake_sleep
        try:
            rl.acquire()  # t=0
            slept = rl.acquire()  # must wait ~5s
        finally:
            youtube_core.time.sleep = orig
        assert slept >= 5.0
        assert sleeps and sleeps[0] >= 5.0


class TestRetryPolicy:
    def test_backoff_grows_and_caps(self):
        rp = RetryPolicy(backoff=1.0, multiplier=2.0, max_backoff=5.0, jitter=0.0)
        assert rp.compute_backoff(0) == 1.0
        assert rp.compute_backoff(1) == 2.0
        assert rp.compute_backoff(2) == 4.0
        assert rp.compute_backoff(3) == 5.0  # capped
        assert rp.compute_backoff(10) == 5.0

    def test_should_retry(self):
        rp = RetryPolicy(max_retries=2)
        assert rp.should_retry(503, 0) is True
        assert rp.should_retry(503, 1) is True
        assert rp.should_retry(503, 2) is False  # exhausted
        assert rp.should_retry(404, 0) is False  # not retryable


# ---------------------------------------------------------------------------
# Request plumbing / error mapping
# ---------------------------------------------------------------------------
class TestRequestPlumbing:
    def test_requires_credentials(self):
        client = YouTubeClient(oauth=None, transport=FakeTransport([]))
        with pytest.raises(AuthenticationError):
            client.request("GET", "/channels", params={"part": "snippet"})

    def test_api_key_authenticates_read(self):
        transport = FakeTransport([(200, {"items": []})])
        client = YouTubeClient(api_key="KEY", transport=transport)
        resp = client.request("GET", "/channels", params={"part": "snippet"})
        assert resp.ok
        url = transport.last_request().full_url
        assert "key=KEY" in url

    def test_bearer_header_attached(self):
        transport = FakeTransport([(200, {"items": []})])
        client = make_client(transport)
        client.request("GET", "/channels", params={"part": "snippet"})
        headers = transport.last_request().headers
        assert headers.get("Authorization") == "Bearer test-access-token"

    def test_retries_on_503_then_succeeds(self):
        transport = FakeTransport(
            [
                (503, {"error": {"errors": [{"reason": "backendError"}], "message": "busy"}}),
                (200, {"items": [{"id": "v1"}]}),
            ]
        )
        client = make_client(transport)
        resp = client.request("GET", "/videos", params={"part": "snippet", "id": "v1"})
        assert resp.ok
        assert len(transport.requests) == 2

    def test_retries_exhausted_raises(self):
        transport = FakeTransport(
            [(503, {"error": {"errors": [{"reason": "backendError"}], "message": "busy"}})]
        )
        client = make_client(transport)
        with pytest.raises(YouTubeAPIError) as exc:
            client.request("GET", "/videos", params={"part": "snippet"})
        assert exc.value.status == 503
        # 1 initial + max_retries(3) = 4 attempts
        assert len(transport.requests) == 4

    def test_network_error_then_success(self):
        transport = FakeTransport(
            [urllib.error.URLError("boom"), (200, {"items": []})]
        )
        client = make_client(transport)
        resp = client.request("GET", "/channels", params={"part": "snippet"})
        assert resp.ok

    def test_network_error_exhausted_raises(self):
        transport = FakeTransport([urllib.error.URLError("down")])
        client = make_client(transport)
        with pytest.raises(YouTubeError):
            client.request("GET", "/channels", params={"part": "snippet"})

    @pytest.mark.parametrize(
        "status,payload,expected",
        [
            (401, {"error": {"errors": [{"reason": "authError"}], "message": "no"}}, AuthenticationError),
            (403, {"error": {"errors": [{"reason": "forbidden"}], "message": "no"}}, ForbiddenError),
            (403, {"error": {"errors": [{"reason": "quotaExceeded"}], "message": "q"}}, QuotaExceededError),
            (404, {"error": {"errors": [{"reason": "notFound"}], "message": "x"}}, NotFoundError),
            (400, {"error": {"errors": [{"reason": "badRequest"}], "message": "x"}}, BadRequestError),
            (429, {"error": {"errors": [{"reason": "rateLimitExceeded"}], "message": "x"}}, QuotaExceededError),
        ],
    )
    def test_error_mapping(self, status, payload, expected):
        transport = FakeTransport([(status, payload)])
        client = make_client(transport)
        with pytest.raises(expected):
            client.request("GET", "/videos", params={"part": "snippet"})


# ---------------------------------------------------------------------------
# Channels
# ---------------------------------------------------------------------------
CHANNEL_PAYLOAD = {
    "items": [
        {
            "id": "UC123",
            "snippet": {
                "title": "Test Channel",
                "description": "desc",
                "customUrl": "@test",
                "publishedAt": "2020-01-01T00:00:00Z",
                "thumbnails": {"default": {"url": "http://img"}},
            },
            "statistics": {
                "subscriberCount": "1000",
                "videoCount": "42",
                "viewCount": "99999",
            },
            "contentDetails": {"relatedPlaylists": {"uploads": "UU123"}},
        }
    ]
}


class TestChannels:
    def test_get_channel_by_id(self):
        transport = FakeTransport([(200, CHANNEL_PAYLOAD)])
        client = make_client(transport)
        channel = client.get_channel(channel_id="UC123")
        assert isinstance(channel, Channel)
        assert channel.id == "UC123"
        assert channel.title == "Test Channel"
        assert channel.subscriber_count == 1000
        assert channel.video_count == 42
        assert channel.uploads_playlist_id == "UU123"

    def test_get_channel_requires_identifier(self):
        client = make_client(FakeTransport([]))
        with pytest.raises(BadRequestError):
            client.get_channel()

    def test_get_channel_not_found(self):
        transport = FakeTransport([(200, {"items": []})])
        client = make_client(transport)
        with pytest.raises(NotFoundError):
            client.get_channel(channel_id="missing")

    def test_get_channel_mine(self):
        transport = FakeTransport([(200, CHANNEL_PAYLOAD)])
        client = make_client(transport)
        client.get_channel(mine=True)
        assert "mine=true" in transport.last_request().full_url

    def test_list_channels(self):
        transport = FakeTransport([(200, CHANNEL_PAYLOAD)])
        client = make_client(transport)
        resp = client.list_channels(ids=["UC123", "UC456"], max_results=10)
        assert len(resp.items()) == 1
        url = transport.last_request().full_url
        assert "id=UC123%2CUC456" in url
        assert "maxResults=10" in url


# ---------------------------------------------------------------------------
# Videos
# ---------------------------------------------------------------------------
VIDEO_PAYLOAD = {
    "items": [
        {
            "id": "vid1",
            "snippet": {
                "title": "My Video",
                "description": "d",
                "channelId": "UC123",
                "channelTitle": "Test Channel",
                "publishedAt": "2021-01-01T00:00:00Z",
                "tags": ["a", "b"],
                "thumbnails": {},
            },
            "statistics": {"viewCount": "10", "likeCount": "2", "commentCount": "1"},
            "status": {"privacyStatus": "public"},
            "contentDetails": {"duration": "PT5M"},
        }
    ]
}


class TestVideos:
    def test_get_video(self):
        transport = FakeTransport([(200, VIDEO_PAYLOAD)])
        client = make_client(transport)
        video = client.get_video("vid1")
        assert isinstance(video, Video)
        assert video.title == "My Video"
        assert video.view_count == 10
        assert video.privacy_status == "public"
        assert video.duration == "PT5M"
        assert video.tags == ["a", "b"]

    def test_get_video_not_found(self):
        transport = FakeTransport([(200, {"items": []})])
        client = make_client(transport)
        with pytest.raises(NotFoundError):
            client.get_video("nope")

    def test_search(self):
        transport = FakeTransport([(200, VIDEO_PAYLOAD)])
        client = make_client(transport)
        resp = client.search("lofi beats", max_results=5)
        url = transport.last_request().full_url
        assert "q=lofi+beats" in url or "q=lofi%20beats" in url
        assert "type=video" in url

    def test_update_video(self):
        transport = FakeTransport([(200, VIDEO_PAYLOAD)])
        client = make_client(transport)
        video = client.update_video(
            "vid1", snippet={"title": "New"}, status={"privacyStatus": "unlisted"}
        )
        assert isinstance(video, Video)
        req = transport.last_request()
        assert req.get_method() == "PUT"
        body = json.loads(req.data.decode())
        assert body["id"] == "vid1"
        assert body["snippet"]["title"] == "New"
        assert body["status"]["privacyStatus"] == "unlisted"

    def test_update_video_requires_a_part(self):
        client = make_client(FakeTransport([]))
        with pytest.raises(BadRequestError):
            client.update_video("vid1")

    def test_delete_video(self):
        transport = FakeTransport([(204, None)])
        client = make_client(transport)
        resp = client.delete_video("vid1")
        assert resp.status == 204
        assert transport.last_request().get_method() == "DELETE"


# ---------------------------------------------------------------------------
# Playlists
# ---------------------------------------------------------------------------
PLAYLIST_PAYLOAD = {
    "items": [
        {
            "id": "PL1",
            "snippet": {
                "title": "Favs",
                "description": "d",
                "channelId": "UC123",
                "publishedAt": "2021-01-01T00:00:00Z",
            },
            "status": {"privacyStatus": "public"},
            "contentDetails": {"itemCount": "7"},
        }
    ]
}


class TestPlaylists:
    def test_get_playlist(self):
        transport = FakeTransport([(200, PLAYLIST_PAYLOAD)])
        client = make_client(transport)
        pl = client.get_playlist("PL1")
        assert isinstance(pl, Playlist)
        assert pl.title == "Favs"
        assert pl.item_count == 7

    def test_create_playlist(self):
        transport = FakeTransport([(200, PLAYLIST_PAYLOAD)])
        client = make_client(transport)
        pl = client.create_playlist("Favs", description="d", privacy_status="public")
        assert isinstance(pl, Playlist)
        body = transport.bodies()[0]
        assert body["snippet"]["title"] == "Favs"
        assert body["status"]["privacyStatus"] == "public"

    def test_update_playlist(self):
        transport = FakeTransport([(200, PLAYLIST_PAYLOAD)])
        client = make_client(transport)
        client.update_playlist("PL1", title="New", privacy_status="private")
        body = transport.bodies()[0]
        assert body["snippet"]["title"] == "New"
        assert body["status"]["privacyStatus"] == "private"

    def test_delete_playlist(self):
        transport = FakeTransport([(204, None)])
        client = make_client(transport)
        client.delete_playlist("PL1")
        assert transport.last_request().get_method() == "DELETE"

    def test_list_playlist_items(self):
        items_payload = {
            "items": [
                {
                    "id": "PLI1",
                    "snippet": {
                        "playlistId": "PL1",
                        "resourceId": {"videoId": "vid1"},
                        "title": "My Video",
                        "position": 0,
                        "publishedAt": "2021-01-01T00:00:00Z",
                    },
                }
            ]
        }
        transport = FakeTransport([(200, items_payload)])
        client = make_client(transport)
        resp = client.list_playlist_items("PL1")
        item = PlaylistItem.from_api(resp.first())
        assert item.video_id == "vid1"
        assert item.playlist_id == "PL1"

    def test_add_video_to_playlist(self):
        items_payload = {
            "id": "PLI2",
            "snippet": {
                "playlistId": "PL1",
                "resourceId": {"videoId": "vid9"},
                "title": "Nine",
                "position": 3,
            },
        }
        transport = FakeTransport([(200, items_payload)])
        client = make_client(transport)
        item = client.add_video_to_playlist("PL1", "vid9", position=3)
        assert isinstance(item, PlaylistItem)
        body = transport.bodies()[0]
        assert body["snippet"]["resourceId"]["videoId"] == "vid9"
        assert body["snippet"]["position"] == 3


# ---------------------------------------------------------------------------
# Live streams
# ---------------------------------------------------------------------------
LIVE_STREAM_PAYLOAD = {
    "items": [
        {
            "id": "stream1",
            "snippet": {"title": "My Stream", "description": "d"},
            "cdn": {
                "frameRate": "30fps",
                "ingestionType": "rtmp",
                "resolution": "1080p",
                "ingestionInfo": {
                    "streamName": "abcd-efgh-ijkl",
                    "ingestionAddress": "rtmp://a.rtmp.youtube.com/live2",
                    "backupIngestionAddress": "rtmp://b.rtmp.youtube.com/live2",
                },
            },
            "status": {"streamStatus": "active"},
        }
    ]
}


class TestLiveStreams:
    def test_create_live_stream(self):
        transport = FakeTransport([(200, LIVE_STREAM_PAYLOAD)])
        client = make_client(transport)
        stream = client.create_live_stream("My Stream", resolution="1080p")
        assert isinstance(stream, LiveStream)
        assert stream.id == "stream1"
        assert stream.stream_key == "abcd-efgh-ijkl"
        assert stream.ingestion_address.startswith("rtmp://")
        body = transport.bodies()[0]
        assert body["cdn"]["resolution"] == "1080p"
        assert body["cdn"]["ingestionType"] == "rtmp"

    def test_create_live_stream_4k(self):
        transport = FakeTransport([(200, LIVE_STREAM_PAYLOAD)])
        client = make_client(transport)
        client.create_live_stream("4K", is_4k=True)
        body = transport.bodies()[0]
        assert body["cdn"]["resolution"] == "2160p"

    def test_get_live_stream(self):
        transport = FakeTransport([(200, LIVE_STREAM_PAYLOAD)])
        client = make_client(transport)
        stream = client.get_live_stream("stream1")
        assert stream.status == "active"

    def test_get_live_stream_not_found(self):
        transport = FakeTransport([(200, {"items": []})])
        client = make_client(transport)
        with pytest.raises(NotFoundError):
            client.get_live_stream("nope")

    def test_delete_live_stream(self):
        transport = FakeTransport([(204, None)])
        client = make_client(transport)
        client.delete_live_stream("stream1")
        assert transport.last_request().get_method() == "DELETE"

    def test_stream_health_healthy(self):
        payload = {
            "items": [
                {
                    "id": "stream1",
                    "status": {"streamStatus": "active"},
                    "statistics": {"frameRate": "30fps", "bitrateBps": "4500000"},
                }
            ]
        }
        transport = FakeTransport([(200, payload)])
        client = make_client(transport)
        health = client.get_stream_health("stream1")
        assert isinstance(health, StreamHealth)
        assert health.status == "active"
        assert health.is_healthy is True
        assert health.bitrate_bps == 4500000

    def test_stream_health_with_configuration_issue(self):
        payload = {
            "items": [
                {
                    "id": "stream1",
                    "status": {
                        "streamStatus": "active",
                        "configurationIssueDetails": ["encoderTooSlow"],
                    },
                }
            ]
        }
        transport = FakeTransport([(200, payload)])
        client = make_client(transport)
        health = client.get_stream_health("stream1")
        assert health.configuration_issue is True
        assert health.reason == "encoderTooSlow"
        assert health.is_healthy is False


# ---------------------------------------------------------------------------
# Live broadcasts + transitions
# ---------------------------------------------------------------------------
def broadcast_payload(status="upcoming", chat="chat1", bound="stream1"):
    return {
        "items": [
            {
                "id": "bcast1",
                "snippet": {
                    "title": "Show",
                    "description": "d",
                    "scheduledStartTime": "2026-01-01T00:00:00Z",
                    "liveChatId": chat,
                    "thumbnails": {"high": {"url": "http://thumb"}},
                },
                "status": {
                    "lifeCycleStatus": status,
                    "privacyStatus": "public",
                    "actualStartTime": "2026-01-01T00:00:05Z",
                },
                "contentDetails": {"boundStreamId": bound},
            }
        ]
    }


class TestLiveBroadcasts:
    def test_create_broadcast_bound_to_stream(self):
        transport = FakeTransport([(200, broadcast_payload())])
        client = make_client(transport)
        b = client.create_live_broadcast(
            "Show",
            scheduled_start_time="2026-01-01T00:00:00Z",
            stream_id="stream1",
        )
        assert isinstance(b, LiveBroadcast)
        assert b.bound_stream_id == "stream1"
        assert b.live_chat_id == "chat1"
        body = transport.bodies()[0]
        assert body["contentDetails"]["boundStreamId"] == "stream1"

    def test_get_broadcast(self):
        transport = FakeTransport([(200, broadcast_payload(status="active"))])
        client = make_client(transport)
        b = client.get_live_broadcast("bcast1")
        assert b.status == "active"

    def test_transition_to_live(self):
        transport = FakeTransport([(200, broadcast_payload(status="active"))])
        client = make_client(transport)
        b = client.transition_broadcast(
            "bcast1", BroadcastTransition.LIVE, stream_id="stream1"
        )
        assert b.status == "active"
        req = transport.last_request()
        assert req.get_method() == "POST"
        assert "/liveBroadcasts/transition" in req.full_url
        assert "broadcastStatus=live" in req.full_url
        assert "streamId=stream1" in req.full_url

    def test_transition_accepts_string(self):
        transport = FakeTransport([(200, broadcast_payload(status="complete"))])
        client = make_client(transport)
        b = client.transition_broadcast("bcast1", "complete")
        assert b.status == "complete"
        assert "broadcastStatus=complete" in transport.last_request().full_url

    def test_update_broadcast(self):
        transport = FakeTransport([(200, broadcast_payload())])
        client = make_client(transport)
        client.update_live_broadcast("bcast1", title="New Title", privacy_status="private")
        body = transport.bodies()[0]
        assert body["snippet"]["title"] == "New Title"
        assert body["status"]["privacyStatus"] == "private"

    def test_delete_broadcast(self):
        transport = FakeTransport([(204, None)])
        client = make_client(transport)
        client.delete_live_broadcast("bcast1")
        assert transport.last_request().get_method() == "DELETE"


# ---------------------------------------------------------------------------
# Live chat
# ---------------------------------------------------------------------------
CHAT_PAYLOAD = {
    "items": [
        {
            "id": "msg1",
            "snippet": {
                "displayMessage": "hello world",
                "publishedAt": "2026-01-01T00:00:00Z",
                "type": "textMessageEvent",
                "authorDetails": {
                    "displayName": "Alice",
                    "channelId": "UC-alice",
                    "isChatModerator": False,
                    "isChatOwner": False,
                },
            },
        },
        {
            "id": "msg2",
            "snippet": {
                "displayMessage": "hi from mod",
                "publishedAt": "2026-01-01T00:00:01Z",
                "type": "textMessageEvent",
                "authorDetails": {
                    "displayName": "Mod",
                    "channelId": "UC-mod",
                    "isChatModerator": True,
                },
            },
        },
    ],
    "nextPageToken": "next-token",
}


class TestLiveChat:
    def test_list_chat_messages(self):
        transport = FakeTransport([(200, CHAT_PAYLOAD)])
        client = make_client(transport)
        messages = client.list_chat_messages("chat1")
        assert len(messages) == 2
        assert isinstance(messages[0], LiveChatMessage)
        assert messages[0].text == "hello world"
        assert messages[0].author == "Alice"
        assert messages[1].is_moderator is True

    def test_send_chat_message(self):
        sent = {
            "id": "msg3",
            "snippet": {
                "displayMessage": "beep boop",
                "authorDetails": {"displayName": "Bot"},
            },
        }
        transport = FakeTransport([(200, sent)])
        client = make_client(transport)
        msg = client.send_live_chat_message("chat1", "beep boop")
        assert isinstance(msg, LiveChatMessage)
        body = transport.bodies()[0]
        assert body["snippet"]["textMessageDetails"]["messageText"] == "beep boop"
        assert body["snippet"]["type"] == "textMessageEvent"

    def test_poll_chat_once_dedupes(self):
        transport = FakeTransport([(200, CHAT_PAYLOAD), (200, CHAT_PAYLOAD)])
        client = make_client(transport)
        seen = set()
        fresh, token = client.poll_chat_once("chat1", seen)
        assert len(fresh) == 2
        assert token == "next-token"
        assert "msg1" in seen
        # Second poll returns no new messages (all seen).
        fresh2, _ = client.poll_chat_once("chat1", seen)
        assert fresh2 == []


# ---------------------------------------------------------------------------
# High-level YouTubeCore facade
# ---------------------------------------------------------------------------
class TestYouTubeCore:
    def _core(self, responses):
        transport = FakeTransport(responses)
        config = OAuth2Config(client_id="cid", client_secret="s")
        core = YouTubeCore(
            config,
            transport=transport,
            token_store={"access_token": "AT", "refresh_token": "RT", "expires_in": 3600},
            retry_policy=RetryPolicy(sleep_func=lambda _: None),
        )
        return core, transport

    def test_is_authenticated(self):
        core, _ = self._core([])
        assert core.is_authenticated is True

    def test_create_scheduled_broadcast(self):
        core, transport = self._core(
            [
                (200, LIVE_STREAM_PAYLOAD),  # create stream
                (200, broadcast_payload()),  # create broadcast
            ]
        )
        stream, broadcast = core.create_scheduled_broadcast("My Show")
        assert isinstance(stream, LiveStream)
        assert isinstance(broadcast, LiveBroadcast)
        # Broadcast body should bind the created stream id.
        bodies = transport.bodies()
        assert bodies[1]["contentDetails"]["boundStreamId"] == "stream1"

    def test_go_live(self):
        core, transport = self._core([(200, broadcast_payload(status="active"))])
        b = core.go_live("bcast1", "stream1")
        assert b.status == "active"
        assert "broadcastStatus=live" in transport.last_request().full_url

    def test_end_broadcast(self):
        core, transport = self._core([(200, broadcast_payload(status="complete"))])
        b = core.end_broadcast("bcast1")
        assert b.status == "complete"
        assert "broadcastStatus=complete" in transport.last_request().full_url

    def test_wait_for_stream_healthy_immediate(self):
        healthy = {
            "items": [
                {"id": "stream1", "status": {"streamStatus": "active"}, "statistics": {}}
            ]
        }
        core, _ = self._core([(200, healthy)])
        health = core.wait_for_stream_healthy("stream1", timeout=1.0, interval=0)
        assert health.is_healthy is True

    def test_wait_for_stream_healthy_times_out(self):
        unhealthy = {
            "items": [
                {
                    "id": "stream1",
                    "status": {
                        "streamStatus": "active",
                        "configurationIssueDetails": ["bad"],
                    },
                }
            ]
        }
        core, _ = self._core([(200, unhealthy)])
        with pytest.raises(YouTubeError):
            core.wait_for_stream_healthy("stream1", timeout=0.05, interval=0.01)


# ---------------------------------------------------------------------------
# Response wrapper
# ---------------------------------------------------------------------------
class TestYouTubeResponse:
    def test_ok_and_items(self):
        resp = YouTubeResponse(status=200, body={"items": [{"id": "a"}]})
        assert resp.ok is True
        assert resp.first()["id"] == "a"
        assert len(resp.items()) == 1

    def test_not_ok(self):
        resp = YouTubeResponse(status=404, body={})
        assert resp.ok is False
        assert resp.first() is None

    def test_etag(self):
        resp = YouTubeResponse(status=200, body={}, headers={"ETag": "abc"})
        assert resp.etag == "abc"


# ---------------------------------------------------------------------------
# Webhook plumbing (PubSubHubbub subscriptions + Atom notification parsing)
# ---------------------------------------------------------------------------
SAMPLE_ATOM_FEED = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2010"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <link rel="self" href="https://www.youtube.com/feeds/videos.xml?channel_id=UC123"/>
  <id>yt:channel:UC123</id>
  <yt:channelId>UC123</yt:channelId>
  <title>Lux Test Channel</title>
  <author><name>Lux Tester</name></author>
  <entry>
    <id>yt:video:abc123</id>
    <yt:videoId>abc123</yt:videoId>
    <yt:channelId>UC123</yt:channelId>
    <title>My New Video</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=abc123"/>
    <author><name>Lux Tester</name></author>
    <published>2026-11-23T08:00:00+00:00</published>
    <updated>2026-11-23T08:05:00+00:00</updated>
    <media:group>
      <media:title>My New Video</media:title>
      <media:player url="https://www.youtube.com/watch?v=abc123"/>
    </media:group>
  </entry>
</feed>
"""


class TestPubSubHubbub:
    def test_topic_url_contains_channel(self):
        hub = yt.PubSubHubbub()
        topic = hub.topic_url("UC123")
        assert "channel_id=UC123" in topic
        assert topic.startswith("https://")

    def test_verify_request_echoes_challenge(self):
        hub = yt.PubSubHubbub()
        vr = hub.verify_request(
            mode="subscribe",
            topic=hub.topic_url("UC123"),
            callback_url="https://example.com/hook",
            challenge="challenge-token-xyz",
            lease_seconds=3600,
        )
        assert vr.verified is True
        assert vr.challenge == "challenge-token-xyz"
        assert vr.lease_seconds == 3600
        assert vr.raw["hub.mode"] == "subscribe"

    def test_verify_request_rejects_unknown_mode(self):
        hub = yt.PubSubHubbub()
        vr = hub.verify_request("deny", "topic", "https://cb", "chal")
        assert vr.verified is False

    def test_subscription_params(self):
        hub = yt.PubSubHubbub()
        params = hub.subscription_params(
            "UC123", "https://example.com/hook", mode="subscribe", lease_seconds=600
        )
        assert params["hub.mode"] == "subscribe"
        assert params["hub.callback"] == "https://example.com/hook"
        assert params["hub.lease_seconds"] == "600"
        assert "channel_id=UC123" in params["hub.topic"]

    def test_parse_notification(self):
        hub = yt.PubSubHubbub()
        note = hub.parse_notification(SAMPLE_ATOM_FEED.encode("utf-8"))
        assert note.video_id == "abc123"
        assert note.channel_id == "UC123"
        assert note.title == "My New Video"
        assert note.link == "https://www.youtube.com/watch?v=abc123"
        assert note.author == "Lux Tester"
        assert note.is_video_upload is True
        assert note.media_group.get("title") == "My New Video"

    def test_parse_notification_accepts_str(self):
        note = yt.WebhookNotification.from_xml(SAMPLE_ATOM_FEED)
        assert note.video_id == "abc123"

    def test_parse_notification_invalid_xml(self):
        with pytest.raises(yt.YouTubeError):
            yt.WebhookNotification.from_xml("<not valid")


class TestWebhookVerifier:
    def test_signature_and_verify_roundtrip(self):
        verifier = yt.WebhookVerifier(b"top-secret")
        body = b'{"hello": "world"}'
        sig = verifier.signature(body, "sha256")
        assert sig.startswith("sha256=")
        assert verifier.verify(body, sig, "sha256") is True

    def test_verify_rejects_wrong_signature(self):
        verifier = yt.WebhookVerifier(b"top-secret")
        body = b"payload"
        assert verifier.verify(body, "sha256=deadbeef", "sha256") is False

    def test_verify_rejects_missing_signature(self):
        verifier = yt.WebhookVerifier(b"top-secret")
        assert verifier.verify(b"payload", None, "sha256") is False

    def test_sha1_algorithm(self):
        verifier = yt.WebhookVerifier("secret-str")
        body = b"data"
        sig = verifier.signature(body, "sha1")
        assert sig.startswith("sha1=")
        assert verifier.verify(body, sig, "sha1") is True

    def test_pubsubhubbub_verify_signature_wrapper(self):
        hub = yt.PubSubHubbub()
        body = b"<feed/>"
        sig = yt.WebhookVerifier(b"k").signature(body, "sha256")
        assert hub.verify_signature(body, sig, b"k", "sha256") is True
        assert hub.verify_signature(body, "sha256=bad", b"k", "sha256") is False


# ---------------------------------------------------------------------------
# Video upload (resumable upload flow)
# ---------------------------------------------------------------------------
class TestVideoUpload:
    def test_initiate_resumable_upload_returns_location(self):
        transport = FakeTransport(
            [(200, {}, {"Location": "https://upload.example/session/1"})]
        )
        client = make_client(transport)
        url = client.initiate_resumable_upload(
            {"snippet": {"title": "T"}, "status": {"privacyStatus": "private"}},
            content_length=1024,
        )
        assert url == "https://upload.example/session/1"
        req = transport.requests[0]
        assert req.get_header("X-upload-content-type") == "video/*"
        assert req.get_header("X-upload-content-length") == "1024"

    def test_initiate_resumable_upload_missing_location_raises(self):
        transport = FakeTransport([(200, {}, {})])
        client = make_client(transport)
        with pytest.raises(YouTubeAPIError):
            client.initiate_resumable_upload({"snippet": {}})

    def test_upload_bytes_single_chunk(self):
        transport = FakeTransport([(200, {"id": "vid1", "snippet": {"title": "T"}})])
        client = make_client(transport)
        media = b"x" * 1000
        resp = client.upload_bytes("https://upload.example/s", media, chunk_size=4096)
        assert resp.status == 200
        assert len(transport.requests) == 1
        req = transport.requests[0]
        assert req.get_header("Content-range") == "bytes 0-999/1000"

    def test_upload_bytes_multiple_chunks(self):
        transport = FakeTransport(
            [
                (308, {}, {}),
                (200, {"id": "vid1", "snippet": {"title": "T"}}, {}),
            ]
        )
        client = make_client(transport)
        media = b"y" * 5000
        resp = client.upload_bytes("https://upload.example/s", media, chunk_size=2048)
        assert resp.status == 200
        assert len(transport.requests) == 3
        ranges = [r.get_header("Content-range") for r in transport.requests]
        assert ranges[0] == "bytes 0-2047/5000"
        assert ranges[-1] == "bytes 4096-4999/5000"

    def test_upload_video_end_to_end(self):
        transport = FakeTransport(
            [
                (200, {}, {"Location": "https://upload.example/s"}),
                (200, {"id": "newvid", "snippet": {"title": "My Video"}}, {}),
            ]
        )
        client = make_client(transport)
        video = client.upload_video(
            title="My Video", media=b"binarydata", description="desc"
        )
        assert isinstance(video, Video)
        assert video.id == "newvid"
        assert video.title == "My Video"
        init_req = transport.requests[0]
        assert init_req.get_method() == "POST"

    def test_upload_metadata_helper(self):
        client = YouTubeClient(api_key="k")
        md = client._upload_metadata(
            title="T", description="D", tags=["a", "b"], privacy_status="public"
        )
        assert md["snippet"]["title"] == "T"
        assert md["snippet"]["tags"] == ["a", "b"]
        assert md["status"]["privacyStatus"] == "public"
