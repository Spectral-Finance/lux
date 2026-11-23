"""
Offline test suite for the Shopify Admin API integration.

All HTTP is mocked via an injectable :class:`ShopifyTransport` (or a fake
``requests``-like session). No live Shopify credentials or network access are
required -- the suite runs fully offline.

Run with::

    pytest -q tests/test_shopify_integration.py
"""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request

import pytest

import shopify_integration as si
from shopify_integration import (
    GraphQLCost,
    GraphQLResponse,
    OrdersResource,
    Page,
    ProductsResource,
    ShopifyAdminClient,
    ShopifyAuthError,
    ShopifyClient,
    ShopifyError,
    ShopifyGraphQLClient,
    ShopifyHTTPError,
    ShopifyNotFoundError,
    ShopifyOAuth,
    ShopifyRateLimitError,
    ShopifyResource,
    ShopifyResponse,
    ShopifyServerError,
    ShopifyTransport,
    ShopifyValidationError,
    paginate,
)

SHOP = "test-shop.myshopify.com"
TOKEN = "shpat_test_token_123"
VERSION = "2024-10"


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------


class FakeTransport(ShopifyTransport):
    """A transport that replays a scripted list of responses.

    Each scripted entry is either:
      * a ``(status, headers, body_obj)`` tuple, or
      * an ``Exception`` instance to raise (to simulate network errors).
    """

    def __init__(self, script, timeout: float = 1.0) -> None:
        super().__init__(timeout=timeout)
        self.script = list(script)
        self.requests = []

    def send(self, request):
        self.requests.append(request)
        if not self.script:
            raise AssertionError("FakeTransport ran out of scripted responses")
        item = self.script.pop(0)
        if isinstance(item, Exception):
            raise item
        status, headers, body = item
        if isinstance(body, (dict, list)):
            raw = json.dumps(body).encode("utf-8")
        elif isinstance(body, bytes):
            raw = body
        else:
            raw = str(body).encode("utf-8")
        return status, headers, raw


class FakeSession:
    """A minimal ``requests.Session``-like object for session-injection tests."""

    def __init__(self, script):
        self.script = list(script)
        self.calls = []

    def request(self, method, url, data=None, headers=None, timeout=None):
        self.calls.append({"method": method, "url": url, "data": data, "headers": headers})
        item = self.script.pop(0)
        status, resp_headers, body = item

        class _Resp:
            pass

        r = _Resp()
        r.status_code = status
        r.headers = resp_headers
        r.content = json.dumps(body).encode("utf-8") if isinstance(body, (dict, list)) else body
        return r


def make_client(script, **kwargs):
    transport = FakeTransport(script)
    client = ShopifyAdminClient(
        shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport, **kwargs
    )
    return client, transport


# ---------------------------------------------------------------------------
# Transport & response primitives
# ---------------------------------------------------------------------------


class TestShopifyResponse:
    def test_ok_and_data(self):
        resp = ShopifyResponse(200, {"id": 1}, {"X-Shopify-Shop-Api-Call-Limit": "10/40"})
        assert resp.ok is True
        assert resp.data == {"id": 1}
        assert resp.json() == {"id": 1}

    def test_not_ok(self):
        assert ShopifyResponse(404, {}).ok is False

    def test_header_case_insensitive(self):
        resp = ShopifyResponse(200, {}, {"Content-Type": "application/json"})
        assert resp.header("content-type") == "application/json"
        assert resp.header("missing", "default") == "default"

    def test_rate_limit_parsing(self):
        resp = ShopifyResponse(
            200, {}, {"X-Shopify-Shop-Api-Call-Limit": "32/40", "Retry-After": "2"}
        )
        rl = resp.rate_limit
        assert rl.used == 32
        assert rl.available == 8
        assert rl.bucket_size == 40
        assert rl.remaining == 8
        assert rl.is_full is False
        assert rl.retry_after == 2.0

    def test_rate_limit_full(self):
        rl = si.RateLimitInfo.from_headers({"X-Shopify-Shop-Api-Call-Limit": "40/40"})
        assert rl.is_full is True

    def test_rate_limit_absent(self):
        assert si.RateLimitInfo.from_headers({}) is None


class TestShopifyResource:
    def test_attribute_access(self):
        r = ShopifyResource({"id": 1, "title": "Shirt"})
        assert r.id == 1
        assert r.title == "Shirt"

    def test_nested_wrapping(self):
        r = ShopifyResource(
            {"id": 1, "variants": [{"price": "10.00"}, {"price": "20.00"}]}
        )
        assert isinstance(r.variants, list)
        assert isinstance(r.variants[0], ShopifyResource)
        assert r.variants[0].price == "10.00"
        assert r.variants[1].price == "20.00"

    def test_mapping_access(self):
        r = ShopifyResource({"id": 1})
        assert r["id"] == 1
        assert "id" in r
        assert r.get("missing", "x") == "x"

    def test_missing_attribute_raises(self):
        r = ShopifyResource({"id": 1})
        with pytest.raises(AttributeError):
            _ = r.nonexistent

    def test_to_dict_roundtrip(self):
        data = {"id": 1, "variants": [{"price": "10.00"}]}
        r = ShopifyResource(data)
        assert r.to_dict() == data
        assert isinstance(r.to_dict()["variants"][0], dict)

    def test_equality(self):
        assert ShopifyResource({"id": 1}) == ShopifyResource({"id": 1})
        assert ShopifyResource({"id": 1}) == {"id": 1}
        assert ShopifyResource({"id": 1}) != ShopifyResource({"id": 2})


# ---------------------------------------------------------------------------
# Auth / headers
# ---------------------------------------------------------------------------


class TestAuth:
    def test_access_token_header(self):
        client, transport = make_client([(200, {}, {"ok": True})])
        client.request("GET", "products")
        req = transport.requests[0]
        assert req.get_header("X-shopify-access-token") == TOKEN

    def test_no_token_no_header(self):
        transport = FakeTransport([(200, {}, {})])
        client = ShopifyAdminClient(shop=SHOP, transport=transport)
        client.request("GET", "products")
        req = transport.requests[0]
        assert req.get_header("X-shopify-access-token") is None

    def test_shop_normalization(self):
        assert si._normalize_shop("https://foo.myshopify.com/") == "foo.myshopify.com"
        assert si._normalize_shop("foo.myshopify.com") == "foo.myshopify.com"

    def test_env_fallback(self, monkeypatch):
        monkeypatch.setenv("SHOPIFY_SHOP", "env-shop.myshopify.com")
        monkeypatch.setenv("SHOPIFY_ACCESS_TOKEN", "env-token")
        client = ShopifyAdminClient()
        assert client.shop == "env-shop.myshopify.com"
        assert client.access_token == "env-token"


# ---------------------------------------------------------------------------
# URL building
# ---------------------------------------------------------------------------


class TestURLBuilding:
    def test_list_url(self):
        client, _ = make_client([(200, {}, {"products": []})])
        url = client._build_url("products", None, None, None, None)
        assert url == f"https://{SHOP}/admin/api/{VERSION}/products.json"

    def test_resource_id_url(self):
        client, _ = make_client([(200, {}, {})])
        url = client._build_url("products", 42, None, None, None)
        assert url.endswith("/products/42.json")

    def test_subresource_url(self):
        client, _ = make_client([(200, {}, {})])
        url = client._build_url("products", 42, "variants", None, None)
        assert url.endswith("/products/42/variants.json")

    def test_query_params(self):
        client, _ = make_client([(200, {}, {})])
        url = client._build_url("products", None, None, {"limit": 10, "status": "open"}, None)
        parsed = urllib.parse.urlparse(url)
        qs = urllib.parse.parse_qs(parsed.query)
        assert qs["limit"] == ["10"]
        assert qs["status"] == ["open"]


# ---------------------------------------------------------------------------
# REST client: success paths
# ---------------------------------------------------------------------------


class TestRESTGet:
    def test_get_product(self):
        client, transport = make_client(
            [(200, {}, {"product": {"id": 1, "title": "Shirt"}})]
        )
        product = client.get("products", 1)
        assert product.id == 1
        assert product.title == "Shirt"
        req = transport.requests[0]
        assert req.method == "GET"
        assert req.full_url.endswith("/products/1.json")


class TestRESTCreate:
    def test_create_product_wraps_in_singular_key(self):
        client, transport = make_client(
            [(201, {}, {"product": {"id": 5, "title": "New"}})]
        )
        product = client.create("products", {"title": "New"})
        assert product.id == 5
        body = json.loads(transport.requests[0].data.decode("utf-8"))
        assert body == {"product": {"title": "New"}}


class TestRESTUpdate:
    def test_update_product(self):
        client, transport = make_client(
            [(200, {}, {"product": {"id": 5, "title": "Updated"}})]
        )
        product = client.update("products", 5, {"title": "Updated"})
        assert product.title == "Updated"
        req = transport.requests[0]
        assert req.method == "PUT"
        body = json.loads(req.data.decode("utf-8"))
        assert body == {"product": {"title": "Updated"}}


class TestRESTDelete:
    def test_delete_product(self):
        client, transport = make_client([(200, {}, {})])
        resp = client.delete("products", 5)
        assert resp.status_code == 200
        assert transport.requests[0].method == "DELETE"


class TestRESTCount:
    def test_count(self):
        client, _ = make_client([(200, {}, {"count": 7})])
        assert client.count("products") == 7


# ---------------------------------------------------------------------------
# REST client: error paths
# ---------------------------------------------------------------------------


class TestErrorMapping:
    def test_404_raises_not_found(self):
        client, _ = make_client([(404, {}, {"error": "Not Found"})])
        with pytest.raises(ShopifyNotFoundError) as exc:
            client.get("products", 999)
        assert exc.value.status_code == 404
        assert exc.value.code == "not_found"

    def test_401_raises_auth_error(self):
        client, _ = make_client([(401, {}, {"error": "Invalid API key"})])
        with pytest.raises(ShopifyAuthError):
            client.request("GET", "products")

    def test_403_raises_auth_error(self):
        client, _ = make_client([(403, {}, {"error": "Forbidden"})])
        with pytest.raises(ShopifyAuthError):
            client.request("GET", "products")

    def test_422_raises_validation_error(self):
        client, _ = make_client(
            [(422, {}, {"errors": {"title": ["can't be blank"]}})]
        )
        with pytest.raises(ShopifyValidationError) as exc:
            client.create("products", {"title": ""})
        assert exc.value.status_code == 422
        assert "title" in str(exc.value.body)

    def test_500_raises_server_error_after_retries(self):
        client, transport = make_client(
            [(500, {}, {"error": "boom"}) for _ in range(4)]
        )
        with pytest.raises(ShopifyServerError):
            client.request("GET", "products")
        # 1 initial + 3 retries = 4 attempts
        assert len(transport.requests) == 4

    def test_400_raises_validation_error(self):
        client, _ = make_client([(400, {}, {"error": "Bad Request"})])
        with pytest.raises(ShopifyValidationError):
            client.request("GET", "products")


# ---------------------------------------------------------------------------
# REST client: retries
# ---------------------------------------------------------------------------


class TestRetries:
    def test_retries_on_500_then_succeeds(self):
        client, transport = make_client(
            [
                (500, {}, {"error": "transient"}),
                (200, {}, {"product": {"id": 1}}),
            ]
        )
        product = client.get("products", 1)
        assert product.id == 1
        assert len(transport.requests) == 2

    def test_retries_on_429_then_succeeds(self):
        client, transport = make_client(
            [
                (429, {"Retry-After": "0"}, {"error": "throttled"}),
                (200, {}, {"product": {"id": 2}}),
            ]
        )
        product = client.get("products", 2)
        assert product.id == 2
        assert len(transport.requests) == 2

    def test_429_exhausts_retries_raises_rate_limit(self):
        client, transport = make_client(
            [(429, {"Retry-After": "0"}, {"error": "throttled"}) for _ in range(4)]
        )
        with pytest.raises(ShopifyRateLimitError) as exc:
            client.request("GET", "products")
        assert exc.value.retry_after == 0.0
        assert len(transport.requests) == 4

    def test_retries_on_network_error_then_succeeds(self):
        client, transport = make_client(
            [
                urllib.error.URLError("connection reset"),
                (200, {}, {"product": {"id": 3}}),
            ]
        )
        product = client.get("products", 3)
        assert product.id == 3
        assert len(transport.requests) == 2

    def test_network_error_exhausts_retries(self):
        client, transport = make_client(
            [urllib.error.URLError("down") for _ in range(4)]
        )
        with pytest.raises(ShopifyError):
            client.request("GET", "products")
        assert len(transport.requests) == 4

    def test_no_retry_on_404(self):
        client, transport = make_client([(404, {}, {"error": "nope"})])
        with pytest.raises(ShopifyNotFoundError):
            client.request("GET", "products")
        assert len(transport.requests) == 1


# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------


class TestPagination:
    def test_paginate_follows_link_header(self):
        link1 = (
            f'<https://{SHOP}/admin/api/{VERSION}/products.json?page_info=CUR2&limit=2>; rel="next"'
        )
        client, transport = make_client(
            [
                (200, {"Link": link1}, {"products": [{"id": 1}, {"id": 2}]}),
                (200, {}, {"products": [{"id": 3}]}),
            ]
        )
        items = list(client.paginate("products", params={"limit": 2}))
        assert [i.id for i in items] == [1, 2, 3]
        assert len(transport.requests) == 2
        # Second request should carry page_info=CUR2
        second_url = transport.requests[1].full_url
        assert "page_info=CUR2" in second_url

    def test_paginate_stops_when_no_link(self):
        client, transport = make_client(
            [(200, {}, {"products": [{"id": 1}, {"id": 2}]})]
        )
        items = list(client.paginate("products"))
        assert len(items) == 2
        assert len(transport.requests) == 1

    def test_paginate_respects_limit(self):
        link = (
            f'<https://{SHOP}/admin/api/{VERSION}/products.json?page_info=NEXT&limit=2>; rel="next"'
        )
        client, _ = make_client(
            [
                (200, {"Link": link}, {"products": [{"id": 1}, {"id": 2}]}),
                (200, {"Link": link}, {"products": [{"id": 3}, {"id": 4}]}),
            ]
        )
        items = list(client.paginate("products", limit=3))
        assert [i.id for i in items] == [1, 2, 3]

    def test_paginate_helper_function(self):
        pages = [
            Page(items=[1, 2], next_cursor="c1", has_next=True),
            Page(items=[3], next_cursor=None, has_next=False),
        ]
        calls = []

        def fetch(cursor):
            calls.append(cursor)
            return pages[0] if cursor is None else pages[1]

        result = list(paginate(fetch))
        assert result == [1, 2, 3]
        assert calls == [None, "c1"]

    def test_next_cursor_from_link_parsing(self):
        link = '<https://x/y.json?page_info=ABC&limit=5>; rel="next"'
        assert si._next_cursor_from_link(link) == "ABC"

    def test_next_cursor_none_when_prev_only(self):
        link = '<https://x/y.json?page_info=ABC>; rel="previous"'
        assert si._next_cursor_from_link(link) is None


# ---------------------------------------------------------------------------
# Resource namespaces
# ---------------------------------------------------------------------------


class TestProductsResource:
    def test_list(self):
        client, _ = make_client(
            [(200, {}, {"products": [{"id": 1}, {"id": 2}]})]
        )
        items = client.products.list()
        assert [i.id for i in items] == [1, 2]

    def test_iter_paginates(self):
        link = (
            f'<https://{SHOP}/admin/api/{VERSION}/products.json?page_info=N&limit=1>; rel="next"'
        )
        client, _ = make_client(
            [
                (200, {"Link": link}, {"products": [{"id": 1}]}),
                (200, {}, {"products": [{"id": 2}]}),
            ]
        )
        items = list(client.products.iter())
        assert [i.id for i in items] == [1, 2]

    def test_variants(self):
        client, _ = make_client(
            [(200, {}, {"variants": [{"id": 10, "price": "9.99"}]})]
        )
        variants = client.products.variants(1)
        assert variants[0].price == "9.99"

    def test_images(self):
        client, _ = make_client(
            [(200, {}, {"images": [{"id": 100, "src": "http://x/y.jpg"}]})]
        )
        images = client.products.images(1)
        assert images[0].src == "http://x/y.jpg"


class TestOrdersResource:
    def test_open_orders(self):
        client, transport = make_client(
            [(200, {}, {"orders": [{"id": 1, "status": "open"}]})]
        )
        orders = client.orders.open()
        assert orders[0].status == "open"
        assert "status=open" in transport.requests[0].full_url

    def test_fulfillments(self):
        client, _ = make_client(
            [(200, {}, {"fulfillments": [{"id": 7}]})]
        )
        f = client.orders.fulfillments(1)
        assert f[0].id == 7

    def test_cancel(self):
        client, transport = make_client([(200, {}, {"order": {"id": 1, "cancelled_at": "x"}})])
        resp = client.orders.cancel(1)
        assert resp.status_code == 200
        assert transport.requests[0].method == "POST"
        assert transport.requests[0].full_url.endswith("/orders/1/cancel.json")

    def test_close(self):
        client, transport = make_client([(200, {}, {"order": {"id": 1, "closed_at": "x"}})])
        client.orders.close(1)
        assert transport.requests[0].full_url.endswith("/orders/1/close.json")


class TestCustomersResource:
    def test_search(self):
        client, transport = make_client(
            [(200, {}, {"customers": [{"id": 1}]})]
        )
        client.customers.search("john@example.com")
        assert "query=john" in transport.requests[0].full_url

    def test_orders(self):
        client, _ = make_client(
            [(200, {}, {"orders": [{"id": 9}]})]
        )
        orders = client.customers.orders(1)
        assert orders[0].id == 9


class TestInventoryResource:
    def test_levels(self):
        client, _ = make_client(
            [(200, {}, {"inventory_levels": [{"available": 5}]})]
        )
        levels = client.inventory.levels(inventory_item_ids=[1, 2], location_ids=[3])
        assert levels[0].available == 5

    def test_adjust(self):
        client, transport = make_client([(200, {}, {"inventory_level": {"available": 10}})])
        client.inventory.adjust(1, 2, 5)
        req = transport.requests[0]
        assert req.full_url.endswith("/inventory_levels/adjust.json")
        body = json.loads(req.data.decode("utf-8"))
        assert body["available_adjustment"] == 5

    def test_set(self):
        client, transport = make_client([(200, {}, {"inventory_level": {"available": 10}})])
        client.inventory.set(1, 2, 10)
        req = transport.requests[0]
        assert req.full_url.endswith("/inventory_levels/set.json")
        body = json.loads(req.data.decode("utf-8"))
        assert body["available"] == 10

    def test_locations(self):
        client, _ = make_client(
            [(200, {}, {"locations": [{"id": 1, "name": "WH"}]})]
        )
        locs = client.inventory.locations()
        assert locs[0].name == "WH"


class TestWebhooksResource:
    def test_create(self):
        client, transport = make_client(
            [(201, {}, {"webhook_subscription": {"id": 1, "topic": "orders/create"}})]
        )
        hook = client.webhooks.create(
            {
                "topic": "orders/create",
                "address": "https://example.com/hook",
                "format": "json",
            }
        )
        assert hook.id == 1
        body = json.loads(transport.requests[0].data.decode("utf-8"))
        assert body["webhook_subscription"]["topic"] == "orders/create"

    def test_topics(self):
        client, _ = make_client([])
        topics = client.webhooks.topics()
        assert "orders/create" in topics
        assert "products/update" in topics


# ---------------------------------------------------------------------------
# GraphQL client
# ---------------------------------------------------------------------------


class TestGraphQL:
    def test_query_success(self):
        transport = FakeTransport(
            [(200, {}, {"data": {"shop": {"name": "Test Shop"}}})]
        )
        gql = ShopifyGraphQLClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        result = gql.execute("{ shop { name } }")
        assert result.data == {"shop": {"name": "Test Shop"}}
        assert result.errors is None
        req = transport.requests[0]
        assert req.method == "POST"
        assert req.full_url.endswith(f"/admin/api/{VERSION}/graphql.json")
        body = json.loads(req.data.decode("utf-8"))
        assert body["query"] == "{ shop { name } }"

    def test_query_with_variables(self):
        transport = FakeTransport([(200, {}, {"data": {"product": {"id": 1}}})])
        gql = ShopifyGraphQLClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        gql.execute("query($id: ID!){ product(id: $id){ id } }", {"id": "1"})
        body = json.loads(transport.requests[0].data.decode("utf-8"))
        assert body["variables"] == {"id": "1"}

    def test_graphql_errors_raise(self):
        transport = FakeTransport(
            [(200, {}, {"errors": [{"message": "Field 'x' doesn't exist"}]})]
        )
        gql = ShopifyGraphQLClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        with pytest.raises(ShopifyHTTPError):
            gql.execute("{ x }")

    def test_graphql_throttle_retry(self):
        throttled = {
            "data": None,
            "extensions": {
                "cost": {
                    "throttleStatus": {"currentlyAvailable": 0, "restoreRate": 50.0}
                }
            },
        }
        ok = {"data": {"shop": {"name": "OK"}}}
        transport = FakeTransport([(200, {}, throttled), (200, {}, ok)])
        gql = ShopifyGraphQLClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        result = gql.execute("{ shop { name } }")
        assert result.data == {"shop": {"name": "OK"}}
        assert len(transport.requests) == 2

    def test_graphql_429_retry(self):
        transport = FakeTransport(
            [
                (429, {"Retry-After": "0"}, {"error": "throttled"}),
                (200, {}, {"data": {"ok": True}}),
            ]
        )
        gql = ShopifyGraphQLClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        result = gql.execute("{ ok }")
        assert result.data == {"ok": True}

    def test_graphql_500_retry_exhaustion(self):
        transport = FakeTransport([(500, {}, {}) for _ in range(4)])
        gql = ShopifyGraphQLClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        with pytest.raises(ShopifyServerError):
            gql.execute("{ ok }")

    def test_graphql_cost_parsing(self):
        cost = GraphQLCost.from_extensions(
            {
                "requestedQueryCost": 1,
                "actualQueryCost": 1,
                "throttleStatus": {"currentlyAvailable": 1000, "restoreRate": 50.0},
            }
        )
        assert cost.requested_query_cost == 1
        assert cost.currently_available == 1000
        assert cost.restore_rate == 50.0
        assert cost.throttle_wait_seconds == 0.0

    def test_graphql_cost_wait_when_empty(self):
        cost = GraphQLCost.from_extensions(
            {"throttleStatus": {"currentlyAvailable": 0, "restoreRate": 50.0}}
        )
        assert cost.throttle_wait_seconds == pytest.approx(0.02)

    def test_graphql_response_throttled_property(self):
        resp = GraphQLResponse(
            200,
            {"extensions": {"cost": {"throttleStatus": {"currentlyAvailable": 0}}}},
        )
        assert resp.throttled is True
        resp2 = GraphQLResponse(200, {"data": {}})
        assert resp2.throttled is False


# ---------------------------------------------------------------------------
# OAuth
# ---------------------------------------------------------------------------


class TestOAuth:
    def test_authorize_url(self):
        oauth = ShopifyOAuth(api_key="key", api_secret="secret", scopes=["read_products", "write_orders"])
        url = oauth.authorize_url(SHOP, "https://app.example.com/cb", state="xyz")
        parsed = urllib.parse.urlparse(url)
        qs = urllib.parse.parse_qs(parsed.query)
        assert qs["client_id"] == ["key"]
        assert qs["scope"] == ["read_products,write_orders"]
        assert qs["redirect_uri"] == ["https://app.example.com/cb"]
        assert qs["state"] == ["xyz"]

    def test_exchange_code(self):
        transport = FakeTransport(
            [(200, {}, {"access_token": "tok", "scope": "read_products"})]
        )
        oauth = ShopifyOAuth(api_key="key", api_secret="secret", transport=transport)
        result = oauth.exchange_code(SHOP, "auth-code")
        assert result["access_token"] == "tok"
        body = urllib.parse.parse_qs(transport.requests[0].data.decode("utf-8"))
        assert body["code"] == ["auth-code"]
        assert body["client_secret"] == ["secret"]

    def test_refresh_token(self):
        transport = FakeTransport([(200, {}, {"access_token": "new-tok"})])
        oauth = ShopifyOAuth(api_key="key", api_secret="secret", transport=transport)
        result = oauth.refresh_token(SHOP, "refresh-me")
        assert result["access_token"] == "new-tok"
        body = urllib.parse.parse_qs(transport.requests[0].data.decode("utf-8"))
        assert body["grant_type"] == ["refresh_token"]
        assert body["refresh_token"] == ["refresh-me"]

    def test_revoke(self):
        transport = FakeTransport([(200, {}, {})])
        oauth = ShopifyOAuth(api_key="key", api_secret="secret", transport=transport)
        oauth.revoke(SHOP, "tok")
        body = urllib.parse.parse_qs(transport.requests[0].data.decode("utf-8"))
        assert body["token"] == ["tok"]

    def test_oauth_error_raises(self):
        transport = FakeTransport([(401, {}, {"error": "invalid_grant"})])
        oauth = ShopifyOAuth(api_key="key", api_secret="secret", transport=transport)
        with pytest.raises(ShopifyAuthError):
            oauth.exchange_code(SHOP, "bad-code")


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


class TestShopifyClientFactory:
    def test_builds_rest_client(self):
        client = ShopifyClient(shop=SHOP, access_token=TOKEN, api_version=VERSION)
        assert isinstance(client.rest, ShopifyAdminClient)
        assert isinstance(client.graphql, ShopifyGraphQLClient)
        assert isinstance(client.products, ProductsResource)
        assert isinstance(client.orders, OrdersResource)

    def test_graphql_mode(self):
        client = ShopifyClient(shop=SHOP, access_token=TOKEN, graphql=True)
        assert isinstance(client.rest, ShopifyGraphQLClient)
        assert client.graphql is client.rest

    def test_delegates_resources(self):
        transport = FakeTransport([(200, {}, {"products": [{"id": 1}]})])
        client = ShopifyClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, transport=transport
        )
        items = client.products.list()
        assert items[0].id == 1


# ---------------------------------------------------------------------------
# Session injection
# ---------------------------------------------------------------------------


class TestSessionInjection:
    def test_session_used_when_provided(self):
        session = FakeSession([(200, {}, {"product": {"id": 1, "title": "S"}})])
        client = ShopifyAdminClient(
            shop=SHOP, access_token=TOKEN, api_version=VERSION, session=session
        )
        product = client.get("products", 1)
        assert product.title == "S"
        assert len(session.calls) == 1
        assert session.calls[0]["method"] == "GET"


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


class TestHelpers:
    def test_singular(self):
        assert si._singular("products") == "product"
        assert si._singular("categories") == "category"
        assert si._singular("orders") == "order"
        assert si._singular("inventory_levels") == "inventory_level"

    def test_extract_items_list(self):
        assert si._extract_items([1, 2], "products") == [1, 2]

    def test_extract_items_wrapped(self):
        assert si._extract_items({"products": [1, 2]}, "products") == [1, 2]

    def test_extract_items_fallback(self):
        assert si._extract_items({"widgets": [1]}, "products") == [1]

    def test_extract_items_empty(self):
        assert si._extract_items({}, "products") == []

    def test_unwrap_resource(self):
        assert si._unwrap_resource({"product": {"id": 1}}, "products") == {"id": 1}

    def test_unwrap_resource_passthrough(self):
        assert si._unwrap_resource({"id": 1}, "products") == {"id": 1}

    def test_parse_body_invalid_json(self):
        assert si._parse_body(b"not json") == "not json"

    def test_parse_body_empty(self):
        assert si._parse_body(b"") == {}

    def test_extract_error_message_error_key(self):
        assert si._extract_error_message({"error": "bad"}) == "bad"

    def test_extract_error_message_errors_key(self):
        assert "field" in si._extract_error_message({"errors": {"field": ["bad"]}})

    def test_extract_error_message_message_key(self):
        assert si._extract_error_message({"message": "oops"}) == "oops"

    def test_extract_error_message_none(self):
        assert si._extract_error_message({}) is None


# ---------------------------------------------------------------------------
# Integration-style: full workflow across resources
# ---------------------------------------------------------------------------


class TestWorkflow:
    def test_full_order_to_fulfillment_flow(self):
        # 1. Create order
        # 2. List open orders
        # 3. Get fulfillments
        client, transport = make_client(
            [
                (201, {}, {"order": {"id": 100, "status": "open"}}),
                (200, {}, {"orders": [{"id": 100, "status": "open"}]}),
                (200, {}, {"fulfillments": [{"id": 5, "status": "success"}]}),
            ]
        )
        order = client.orders.create({"line_items": [{"variant_id": 1, "quantity": 1}]})
        assert order.id == 100

        open_orders = client.orders.open()
        assert open_orders[0].id == 100

        fulfillments = client.orders.fulfillments(100)
        assert fulfillments[0].status == "success"
        assert len(transport.requests) == 3
