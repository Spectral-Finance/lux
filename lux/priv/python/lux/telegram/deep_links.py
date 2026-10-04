"""
Deep linking engine for Telegram Bot and Web App entrypoints.

Handles start payloads (t.me/bot?start=PAYLOAD) and Mini App payloads (startapp=PAYLOAD),
parameter serialization/deserialization, cryptographic HMAC signatures, referral and affiliate
attribution tracking, and action routing.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import urllib.parse
import zlib
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple


class DeepLinkError(Exception):
    """Base exception for deep link parsing errors."""
    pass


class DeepLinkSecurityError(DeepLinkError):
    """Raised when deep link signature verification fails."""
    pass


@dataclass
class ParsedDeepLink:
    """Decoded and validated deep link information."""
    raw_payload: str
    action: str
    params: Dict[str, Any] = field(default_factory=dict)
    referrer_id: Optional[int] = None
    campaign: Optional[str] = None
    utm_source: Optional[str] = None
    utm_medium: Optional[str] = None
    auth_token: Optional[str] = None
    is_app_link: bool = False
    is_verified: bool = False


class DeepLinkHandler:
    """Production handler for Telegram deep links and start payloads."""

    def __init__(self, secret_key: Optional[str] = None):
        self.secret_key = secret_key
        self._action_handlers: Dict[str, Callable[[ParsedDeepLink, Any], Any]] = {}

    def register_action(self, action: str, handler: Callable[[ParsedDeepLink, Any], Any]) -> None:
        """Registers a callback handler for a specific deep link action."""
        self._action_handlers[action.lower()] = handler

    def parse(self, text_or_url: str, verify_hmac: bool = True) -> ParsedDeepLink:
        """Parses a full URL or a /start raw payload string into a ParsedDeepLink.

        Supports:
        - Full URL: https://t.me/BotName?start=PAYLOAD or tg://resolve?domain=BotName&startapp=PAYLOAD
        - Raw command text: /start PAYLOAD
        - Plain payload string: ref_12345 or base64 encoded
        """
        if not text_or_url:
            raise DeepLinkError("Empty deep link input")

        raw_str = text_or_url.strip()
        is_app = False
        payload = ""

        # 1. URL extraction
        if "://" in raw_str or raw_str.startswith("t.me/"):
            url_to_parse = raw_str if "://" in raw_str else f"https://{raw_str}"
            parsed_url = urllib.parse.urlparse(url_to_parse)
            query_params = urllib.parse.parse_qs(parsed_url.query)

            if "startapp" in query_params:
                payload = query_params["startapp"][0]
                is_app = True
            elif "start" in query_params:
                payload = query_params["start"][0]
            else:
                payload = parsed_url.fragment or ""
        # 2. Command extraction: /start PAYLOAD
        elif raw_str.startswith("/start"):
            parts = raw_str.split(maxsplit=1)
            payload = parts[1] if len(parts) > 1 else ""
        else:
            payload = raw_str

        if not payload:
            return ParsedDeepLink(
                raw_payload="",
                action="default",
                is_app_link=is_app,
                is_verified=True,
            )

        return self._decode_payload(payload, is_app=is_app, verify_hmac=verify_hmac)

    def _decode_payload(self, payload: str, is_app: bool, verify_hmac: bool) -> ParsedDeepLink:
        """Decodes raw payload using standard patterns, base64, or compressed JSON."""
        # Check for signature attachment (payload.sig)
        clean_payload = payload
        is_verified = False

        if "." in payload:
            data_part, sig_part = payload.rsplit(".", 1)
            if self.secret_key and len(sig_part) == 8:  # 8-char short HMAC
                expected_sig = self._generate_short_hmac(data_part, self.secret_key)
                if hmac.compare_digest(sig_part, expected_sig):
                    is_verified = True
                    clean_payload = data_part
                elif verify_hmac:
                    raise DeepLinkSecurityError(f"Invalid deep link signature for payload '{payload}'")

        # Case 1: Base64URL-encoded JSON or compressed payload
        if clean_payload.startswith("b64_") or clean_payload.startswith("z_"):
            try:
                return self._decode_encoded_payload(clean_payload, is_app, is_verified)
            except Exception:
                pass

        # Case 2: Structured underscore notation (e.g. ref_12345, trade_ETH_buy_100, auth_tokenXYZ)
        if "_" in clean_payload:
            parts = clean_payload.split("_")
            action = parts[0].lower()
            params: Dict[str, Any] = {}
            referrer_id = None
            campaign = None
            auth_token = None

            if action in ("ref", "referral") and len(parts) >= 2:
                try:
                    referrer_id = int(parts[1])
                    params["referrer_id"] = referrer_id
                    if len(parts) >= 3:
                        campaign = parts[2]
                        params["campaign"] = campaign
                except ValueError:
                    params["ref_code"] = parts[1]
            elif action == "auth" and len(parts) >= 2:
                auth_token = parts[1]
                params["auth_token"] = auth_token
            elif action == "trade" and len(parts) >= 3:
                params["asset"] = parts[1]
                params["side"] = parts[2]
                if len(parts) >= 4:
                    params["amount"] = parts[3]
            else:
                # Generic positional key-value pairs
                for i in range(1, len(parts)):
                    params[f"param_{i}"] = parts[i]

            return ParsedDeepLink(
                raw_payload=payload,
                action=action,
                params=params,
                referrer_id=referrer_id,
                campaign=campaign,
                auth_token=auth_token,
                is_app_link=is_app,
                is_verified=is_verified,
            )

        # Case 3: Simple word action (e.g. /start help, /start connect)
        return ParsedDeepLink(
            raw_payload=payload,
            action=clean_payload.lower(),
            params={"raw": clean_payload},
            is_app_link=is_app,
            is_verified=is_verified,
        )

    def _decode_encoded_payload(self, encoded: str, is_app: bool, is_verified: bool) -> ParsedDeepLink:
        """Decodes b64_ or z_ formatted payloads."""
        if encoded.startswith("z_"):
            raw_b64 = encoded[2:]
            # Base64url decode + zlib decompress
            padded = raw_b64 + "=" * (-len(raw_b64) % 4)
            compressed_bytes = base64.urlsafe_b64decode(padded.encode())
            decompressed = zlib.decompress(compressed_bytes).decode("utf-8")
            data = json.loads(decompressed)
        elif encoded.startswith("b64_"):
            raw_b64 = encoded[4:]
            padded = raw_b64 + "=" * (-len(raw_b64) % 4)
            json_str = base64.urlsafe_b64decode(padded.encode()).decode("utf-8")
            data = json.loads(json_str)
        else:
            raise ValueError("Unsupported encoding prefix")

        action = data.get("action", "default")
        params = data.get("params", {})
        referrer_id = data.get("referrer_id") or params.get("referrer_id")
        campaign = data.get("campaign") or params.get("campaign")
        utm_source = data.get("utm_source") or params.get("utm_source")
        utm_medium = data.get("utm_medium") or params.get("utm_medium")
        auth_token = data.get("auth_token") or params.get("auth_token")

        return ParsedDeepLink(
            raw_payload=encoded,
            action=action,
            params=params,
            referrer_id=int(referrer_id) if referrer_id else None,
            campaign=campaign,
            utm_source=utm_source,
            utm_medium=utm_medium,
            auth_token=auth_token,
            is_app_link=is_app,
            is_verified=is_verified,
        )

    def create_payload(
        self,
        action: str,
        params: Optional[Dict[str, Any]] = None,
        compress: bool = False,
        sign: bool = False,
    ) -> str:
        """Serializes action and parameters into a compact Telegram-safe payload string (<= 64 chars when possible)."""
        param_dict = params or {}

        # If simple referral
        if action.lower() in ("ref", "referral") and "referrer_id" in param_dict and len(param_dict) <= 2:
            ref_id = param_dict["referrer_id"]
            camp = f"_{param_dict['campaign']}" if "campaign" in param_dict else ""
            raw = f"ref_{ref_id}{camp}"
        # If simple auth
        elif action.lower() == "auth" and "auth_token" in param_dict and len(param_dict) == 1:
            raw = f"auth_{param_dict['auth_token']}"
        # If simple trade
        elif action.lower() == "trade" and "asset" in param_dict and "side" in param_dict and len(param_dict) <= 3:
            amt = f"_{param_dict['amount']}" if "amount" in param_dict else ""
            raw = f"trade_{param_dict['asset']}_{param_dict['side']}{amt}"
        else:
            # JSON packaging
            payload_data = {"action": action, "params": param_dict}
            json_bytes = json.dumps(payload_data, separators=(",", ":")).encode("utf-8")

            if compress or len(json_bytes) > 40:
                compressed = zlib.compress(json_bytes, level=9)
                b64 = base64.urlsafe_b64encode(compressed).decode("utf-8").rstrip("=")
                raw = f"z_{b64}"
            else:
                b64 = base64.urlsafe_b64encode(json_bytes).decode("utf-8").rstrip("=")
                raw = f"b64_{b64}"

        if sign and self.secret_key:
            sig = self._generate_short_hmac(raw, self.secret_key)
            return f"{raw}.{sig}"

        return raw

    def create_deep_link(
        self,
        bot_username: str,
        action: str,
        params: Optional[Dict[str, Any]] = None,
        is_app: bool = False,
        sign: bool = False,
    ) -> str:
        """Constructs a complete clickable Telegram deep link."""
        payload = self.create_payload(action, params, sign=sign)
        clean_bot = bot_username.lstrip("@")
        param_name = "startapp" if is_app else "start"
        return f"https://t.me/{clean_bot}?{param_name}={payload}"

    def dispatch(self, parsed: ParsedDeepLink, context: Any = None) -> Any:
        """Routes parsed deep link to its registered action handler."""
        action = parsed.action.lower()
        if action in self._action_handlers:
            return self._action_handlers[action](parsed, context)
        if "default" in self._action_handlers:
            return self._action_handlers["default"](parsed, context)
        return None

    @staticmethod
    def _generate_short_hmac(data: str, secret: str) -> str:
        """Generates an 8-character hex HMAC tag."""
        h = hmac.new(secret.encode("utf-8"), data.encode("utf-8"), hashlib.sha256)
        return h.hexdigest()[:8]
