"""
Unit tests for DeepLinkHandler, start payloads, HMAC verification, and parameter codecs.
"""

import pytest
from lux.telegram.deep_links import (
    DeepLinkHandler,
    DeepLinkSecurityError,
    ParsedDeepLink,
)


@pytest.fixture
def handler():
    return DeepLinkHandler(secret_key="secret-key-12345")


def test_parse_referral_deep_link(handler):
    link = "https://t.me/LuxDeFiBot?start=ref_98765_twitter"
    parsed = handler.parse(link)
    assert parsed.action == "ref"
    assert parsed.referrer_id == 98765
    assert parsed.campaign == "twitter"
    assert parsed.params["referrer_id"] == 98765


def test_parse_startapp_deep_link(handler):
    link = "https://t.me/LuxDeFiBot?startapp=trade_ETH_buy_500"
    parsed = handler.parse(link)
    assert parsed.is_app_link is True
    assert parsed.action == "trade"
    assert parsed.params["asset"] == "ETH"
    assert parsed.params["side"] == "buy"
    assert parsed.params["amount"] == "500"


def test_parse_auth_deep_link(handler):
    parsed = handler.parse("/start auth_sessiontokenabc123")
    assert parsed.action == "auth"
    assert parsed.auth_token == "sessiontokenabc123"


def test_compressed_and_base64_payloads(handler):
    payload_data = {"action": "vault_deposit", "params": {"vault_id": 42, "asset": "USDC"}}
    raw_payload = handler.create_payload("vault_deposit", params={"vault_id": 42, "asset": "USDC"}, compress=True)
    assert raw_payload.startswith("z_")

    parsed = handler.parse(raw_payload)
    assert parsed.action == "vault_deposit"
    assert parsed.params["vault_id"] == 42
    assert parsed.params["asset"] == "USDC"


def test_hmac_signature_verification_and_tampering(handler):
    signed_payload = handler.create_payload("trade", params={"asset": "ETH", "side": "buy"}, sign=True)
    assert "." in signed_payload

    # Valid payload parses successfully
    parsed = handler.parse(signed_payload, verify_hmac=True)
    assert parsed.is_verified is True
    assert parsed.action == "trade"

    # Tampered payload fails
    tampered = signed_payload[:-2] + "ff"
    with pytest.raises(DeepLinkSecurityError):
        handler.parse(tampered, verify_hmac=True)


def test_create_deep_link(handler):
    url = handler.create_deep_link("LuxBot", "ref", {"referrer_id": 1234, "campaign": "promo"})
    assert url == "https://t.me/LuxBot?start=ref_1234_promo"

    app_url = handler.create_deep_link("LuxBot", "trade", {"asset": "SOL", "side": "sell"}, is_app=True)
    assert app_url == "https://t.me/LuxBot?startapp=trade_SOL_sell"


def test_action_dispatch(handler):
    executed = []

    def handle_trade(parsed: ParsedDeepLink, ctx: dict):
        executed.append(parsed.params["asset"])
        return "trade_routed"

    handler.register_action("trade", handle_trade)

    parsed = handler.parse("/start trade_BTC_buy")
    result = handler.dispatch(parsed, {})
    assert result == "trade_routed"
    assert executed == ["BTC"]
