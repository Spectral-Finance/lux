"""
Coinbase Advanced Trade Dual Authentication Handler.

Supports both:
1. Modern CDP (Cloud Developer Platform) API Keys:
   - Uses ECDSA P-256 (ES256) JWTs with `iss="cdp"`, `sub=api_key_name`, `nbf`, `exp`, and `uri`.
2. Legacy API Key & Secret:
   - Uses HMAC-SHA256 timestamp signature over `timestamp + method + path + body`.
"""

import base64
import hashlib
import hmac
import os
import secrets
import time
from typing import Any, Dict, List, Optional
import jwt


class CoinbaseAuth:
    """
    Unified Authentication Provider for Coinbase Advanced Trade REST & WebSocket.
    
    Can be initialized with either:
    - CDP API credentials: `api_key_name` and `private_key` (PEM string or file path).
    - Legacy API credentials: `api_key`, `api_secret`, and optional `passphrase`.
    """

    def __init__(
        self,
        api_key_name: Optional[str] = None,
        private_key: Optional[str] = None,
        api_key: Optional[str] = None,
        api_secret: Optional[str] = None,
        passphrase: Optional[str] = None,
    ):
        # CDP Credentials
        self.api_key_name = api_key_name or os.getenv("COINBASE_CDP_KEY_NAME") or os.getenv("CDP_API_KEY_NAME")
        raw_priv_key = private_key or os.getenv("COINBASE_CDP_PRIVATE_KEY") or os.getenv("CDP_PRIVATE_KEY")
        self.private_key = self._load_private_key(raw_priv_key)

        # Legacy Credentials
        self.api_key = api_key or os.getenv("COINBASE_API_KEY")
        self.api_secret = api_secret or os.getenv("COINBASE_API_SECRET")
        self.passphrase = passphrase or os.getenv("COINBASE_PASSPHRASE")

    @classmethod
    def from_env(cls) -> "CoinbaseAuth":
        """Create CoinbaseAuth instance automatically from environment variables."""
        return cls()

    def _load_private_key(self, raw_key: Optional[str]) -> Optional[str]:
        if not raw_key:
            return None
        # Check if raw_key is a file path
        if os.path.exists(raw_key):
            try:
                with open(raw_key, "r", encoding="utf-8") as f:
                    return f.read().strip()
            except Exception:
                pass
        # Normalize escaped newlines if passed via environment variable
        cleaned = raw_key.replace("\\n", "\n").strip()
        return cleaned

    @property
    def is_cdp(self) -> bool:
        """True if modern CDP ECDSA credentials are configured."""
        return bool(self.api_key_name and self.private_key)

    @property
    def is_legacy(self) -> bool:
        """True if legacy HMAC-SHA256 credentials are configured."""
        return bool(self.api_key and self.api_secret)

    @property
    def is_authenticated(self) -> bool:
        """True if either auth method is configured."""
        return self.is_cdp or self.is_legacy

    def generate_cdp_jwt(
        self,
        method: str,
        path: str,
        host: str = "api.coinbase.com",
        expires_in: int = 120,
    ) -> str:
        """
        Generate an ECDSA P-256 JWT for Coinbase CDP API request.
        
        Args:
            method: HTTP method (e.g. 'GET', 'POST')
            path: Request path (e.g. '/api/v3/brokerage/accounts')
            host: Hostname (default: 'api.coinbase.com')
            expires_in: Expiry window in seconds (default: 120)
            
        Returns:
            Encoded JWT token string.
        """
        if not self.is_cdp:
            raise ValueError("CDP credentials (api_key_name and private_key) are required to generate CDP JWT.")

        now = int(time.time())
        # Clean path formatting
        clean_path = path if path.startswith("/") else f"/{path}"
        uri = f"{method.upper()} {host}{clean_path}"

        payload = {
            "iss": "cdp",
            "nbf": now,
            "exp": now + expires_in,
            "sub": self.api_key_name,
            "uri": uri,
        }

        headers = {
            "alg": "ES256",
            "typ": "JWT",
            "kid": self.api_key_name,
            "nonce": secrets.token_hex(16),
        }

        token = jwt.encode(
            payload=payload,
            key=self.private_key,
            algorithm="ES256",
            headers=headers,
        )
        return token if isinstance(token, str) else token.decode("utf-8")

    def generate_legacy_signature(
        self,
        timestamp: str,
        method: str,
        path: str,
        body: str = "",
    ) -> str:
        """
        Generate HMAC-SHA256 signature for legacy Coinbase API authentication.
        
        Args:
            timestamp: Epoch timestamp string
            method: HTTP method
            path: Request URI path
            body: Serialized JSON request body
            
        Returns:
            Hex or Base64 signature string.
        """
        if not self.is_legacy:
            raise ValueError("Legacy credentials (api_key and api_secret) are required for HMAC signature.")

        clean_path = path if path.startswith("/") else f"/{path}"
        message = f"{timestamp}{method.upper()}{clean_path}{body}".encode("utf-8")

        # Try base64 decoded secret first (Coinbase Exchange style), fallback to raw utf-8 (Advanced Trade legacy)
        try:
            decoded_secret = base64.b64decode(self.api_secret)
            hmac_obj = hmac.new(decoded_secret, message, hashlib.sha256)
            return base64.b64encode(hmac_obj.digest()).decode("utf-8")
        except Exception:
            hmac_obj = hmac.new(self.api_secret.encode("utf-8"), message, hashlib.sha256)
            return hmac_obj.hexdigest()

    def get_auth_headers(
        self,
        method: str,
        path: str,
        body: str = "",
        host: str = "api.coinbase.com",
    ) -> Dict[str, str]:
        """
        Generate required authentication headers for an outgoing REST request.
        
        Returns dictionary of HTTP headers.
        """
        if not self.is_authenticated:
            return {}

        headers: Dict[str, str] = {}

        if self.is_cdp:
            jwt_token = self.generate_cdp_jwt(method, path, host=host)
            headers["Authorization"] = f"Bearer {jwt_token}"
            if self.api_key_name:
                headers["CB-ACCESS-KEY"] = self.api_key_name
        elif self.is_legacy:
            timestamp = str(int(time.time()))
            signature = self.generate_legacy_signature(timestamp, method, path, body)
            headers["CB-ACCESS-KEY"] = self.api_key or ""
            headers["CB-ACCESS-SIGN"] = signature
            headers["CB-ACCESS-TIMESTAMP"] = timestamp
            if self.passphrase:
                headers["CB-ACCESS-PASSPHRASE"] = self.passphrase

        return headers

    def get_ws_auth_payload(
        self,
        channel: str,
        product_ids: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """
        Generate authentication fields to include in a WebSocket subscription message.
        """
        if not self.is_authenticated:
            return {}

        if self.is_cdp:
            # WebSocket JWT URI claim for Advanced Trade WS
            jwt_token = self.generate_cdp_jwt(
                method="GET",
                path=f"/ws/{channel}",
                host="advanced-trade-ws.coinbase.com",
                expires_in=120,
            )
            return {"jwt": jwt_token}

        if self.is_legacy:
            timestamp = str(int(time.time()))
            # Standard WS legacy signature format
            msg = f"{timestamp}{channel}" + (",".join(product_ids) if product_ids else "")
            try:
                secret_bytes = base64.b64decode(self.api_secret)
                sig = base64.b64encode(hmac.new(secret_bytes, msg.encode("utf-8"), hashlib.sha256).digest()).decode("utf-8")
            except Exception:
                sig = hmac.new(self.api_secret.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).hexdigest()

            payload = {
                "api_key": self.api_key,
                "timestamp": timestamp,
                "signature": sig,
            }
            if self.passphrase:
                payload["passphrase"] = self.passphrase
            return payload

        return {}
