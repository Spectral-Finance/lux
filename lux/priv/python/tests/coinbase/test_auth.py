"""
Unit tests for Coinbase Advanced Trade Authentication Handler.
"""

import base64
import hashlib
import hmac
import time
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization
import jwt
import pytest

from lux.coinbase.auth import CoinbaseAuth


@pytest.fixture
def sample_ec_private_key_pem():
    """Generate a valid ECDSA P-256 private key in PEM format."""
    key = ec.generate_private_key(ec.SECP256R1())
    pem_bytes = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return pem_bytes.decode("utf-8"), key


def test_auth_initialization_empty():
    auth = CoinbaseAuth()
    assert not auth.is_authenticated
    assert not auth.is_cdp
    assert not auth.is_legacy
    assert auth.get_auth_headers("GET", "/test") == {}


def test_legacy_hmac_signature():
    api_key = "test_api_key_123"
    api_secret = base64.b64encode(b"my_secret_key_bytes_1234567890").decode("utf-8")
    auth = CoinbaseAuth(api_key=api_key, api_secret=api_secret, passphrase="pass")

    assert auth.is_legacy
    assert not auth.is_cdp
    assert auth.is_authenticated

    timestamp = str(int(time.time()))
    method = "GET"
    path = "/api/v3/brokerage/accounts"
    body = ""

    sig = auth.generate_legacy_signature(timestamp, method, path, body)
    assert isinstance(sig, str)
    assert len(sig) > 0

    # Verify signature independently
    expected_msg = f"{timestamp}GET{path}{body}".encode("utf-8")
    expected_sig = base64.b64encode(
        hmac.new(base64.b64decode(api_secret), expected_msg, hashlib.sha256).digest()
    ).decode("utf-8")
    assert sig == expected_sig

    headers = auth.get_auth_headers(method, path, body)
    assert headers["CB-ACCESS-KEY"] == api_key
    assert headers["CB-ACCESS-SIGN"] == sig
    assert headers["CB-ACCESS-TIMESTAMP"] == timestamp
    assert headers["CB-ACCESS-PASSPHRASE"] == "pass"


def test_cdp_jwt_generation(sample_ec_private_key_pem):
    pem_str, ec_key = sample_ec_private_key_pem
    key_name = "organizations/org-123/apiKeys/key-456"

    auth = CoinbaseAuth(api_key_name=key_name, private_key=pem_str)
    assert auth.is_cdp
    assert not auth.is_legacy
    assert auth.is_authenticated

    method = "POST"
    path = "/api/v3/brokerage/orders"
    host = "api.coinbase.com"

    token = auth.generate_cdp_jwt(method, path, host=host, expires_in=120)
    assert isinstance(token, str)

    # Decode and verify token
    decoded = jwt.decode(
        token,
        ec_key.public_key(),
        algorithms=["ES256"],
        options={"verify_aud": False},
    )

    assert decoded["iss"] == "cdp"
    assert decoded["sub"] == key_name
    assert decoded["uri"] == f"POST {host}{path}"
    assert decoded["exp"] > decoded["nbf"]

    headers = auth.get_auth_headers(method, path, host=host)
    assert "Authorization" in headers
    assert headers["Authorization"].startswith("Bearer ")
    assert headers["CB-ACCESS-KEY"] == key_name


def test_ws_auth_payload(sample_ec_private_key_pem):
    pem_str, _ = sample_ec_private_key_pem
    key_name = "organizations/org-123/apiKeys/key-456"

    # CDP WS Auth
    cdp_auth = CoinbaseAuth(api_key_name=key_name, private_key=pem_str)
    ws_payload = cdp_auth.get_ws_auth_payload("user", ["BTC-USD"])
    assert "jwt" in ws_payload
    assert ws_payload["jwt"].startswith("ey")

    # Legacy WS Auth
    api_secret = base64.b64encode(b"secret_key_123").decode("utf-8")
    legacy_auth = CoinbaseAuth(api_key="api_key_1", api_secret=api_secret)
    legacy_ws_payload = legacy_auth.get_ws_auth_payload("ticker", ["BTC-USD", "ETH-USD"])
    assert legacy_ws_payload["api_key"] == "api_key_1"
    assert "signature" in legacy_ws_payload
    assert "timestamp" in legacy_ws_payload
