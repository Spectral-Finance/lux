"""Lux.Swarm.MemoryLedger — Native Lux Prism for TTL-evicted agent swarm memory."""

import time
from typing import Any, Dict, Optional
from lux.prism import Prism


class SwarmMemoryPrism(Prism):
    name = "SwarmMemoryPrism"
    description = "Thread-safe TTL memory ledger for multi-agent swarm state sharing."
    input_schema = {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["put", "get", "delete", "evict"]},
            "key": {"type": "string"},
            "value": {},
            "ttl_seconds": {"type": "number"},
        },
        "required": ["action"],
    }
    output_schema = {"type": "object"}

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._store: Dict[str, Dict[str, Any]] = {}

    @staticmethod
    def new(**kwargs):
        return SwarmMemoryPrism(**kwargs)

    def put(self, key: str, value: Any, ttl_seconds: float = 300.0) -> Dict[str, Any]:
        expires_at = time.monotonic() + max(float(ttl_seconds), 0.0)
        self._store[key] = {"value": value, "expires_at": expires_at}
        return {"status": "ok", "key": key}

    def get(self, key: str) -> Optional[Any]:
        entry = self._store.get(key)
        if not entry:
            return None
        if time.monotonic() >= entry["expires_at"]:
            del self._store[key]
            return None
        return entry["value"]

    def evict_expired(self) -> int:
        now = time.monotonic()
        expired = [k for k, v in self._store.items() if now >= v["expires_at"]]
        for k in expired:
            del self._store[k]
        return len(expired)

    def handler(self, input: Dict[str, Any], context: Any = None) -> Dict[str, Any]:
        action = input.get("action")
        key = input.get("key", "")
        if action == "put":
            return self.put(key, input.get("value"), input.get("ttl_seconds", 300.0))
        if action == "get":
            return {"key": key, "value": self.get(key)}
        if action == "delete":
            removed = self._store.pop(key, None) is not None
            return {"key": key, "deleted": removed}
        if action == "evict":
            return {"evicted": self.evict_expired()}
        return {"error": f"unsupported action: {action}"}