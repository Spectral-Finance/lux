"""
bench.py — criterion-free performance benchmarks for telegram_prisms.

Run:  python3 bench.py

Uses stdlib ``timeit`` only (no third-party deps). Measures the hot paths that
matter for a Telegram bot: JSON envelope decoding, multipart encoding, rate
limiter acquire, and a full prism call against an in-memory fake transport.
"""

import json
import os
import sys
import timeit

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from telegram_prisms import (  # noqa: E402
    EventEmitter,
    MessagePrism,
    RateLimiter,
    TelegramHTTP,
)


class _NullTransport:
    """A transport that returns a canned success envelope (no network)."""

    _BODY = json.dumps({"ok": True, "result": {"message_id": 1}}).encode()

    def __init__(self):
        self.calls = 0

    def __call__(self, method, url, headers, body):
        self.calls += 1
        return 200, {}, self._BODY


def _http():
    return TelegramHTTP("123:test", transport=_NullTransport(),
                        sleep_fn=lambda s: None)


def bench(name, stmt, setup, number):
    timer = timeit.Timer(stmt, setup=setup)
    total = timer.timeit(number=number)
    per = total / number
    print(f"  {name:<42} {per * 1e6:8.2f} us/op  ({number} ops)")
    return per


def main():
    print("telegram_prisms performance benchmarks (stdlib timeit)\n")

    body = json.dumps({"ok": True, "result": {"message_id": 1}}).encode()

    # 1. JSON envelope decode (the per-call hot path).
    bench("json envelope decode",
          "json.loads(body)",
          f"import json; body={body!r}",
          number=200000)

    # 2. Multipart encoding (media upload path).
    fields = {"chat_id": "c", "caption": "hi"}
    files = {"photo": b"\x89PNG" * 1024}
    bench("multipart encode (4KB file)",
          "TelegramHTTP._encode_multipart(fields, files)",
          ("from telegram_prisms import TelegramHTTP; "
           f"fields={fields!r}; files={files!r}"),
          number=2000)

    # 3. Rate limiter acquire (uncontended). Use a fresh limiter each op so the
    #    bucket never drains and the call never sleeps.
    bench("rate limiter acquire (uncontended)",
          "RateLimiter().acquire('POST sendMessage')",
          "from telegram_prisms import RateLimiter",
          number=50000)

    # 4. Full prism call (send_message) against fake transport. We build the
    #    prism once in the setup string (no repr of live objects) and use a
    #    generous bucket so acquire() never blocks.
    bench("MessagePrism.send_message (fake)",
          "p.send_message('c', 'hello')",
          ("from telegram_prisms import MessagePrism, TelegramHTTP, "
           "EventEmitter, RateLimiter\n"
           "class _T:\n"
           "    def __call__(self, m, u, h, b):\n"
           "        return 200, {}, b'{\"ok\": true, \"result\": "
           "{\"message_id\": 1}}'\n"
           "rl = RateLimiter()\n"
           "rl._buckets['POST sendMessage'] = "
           "__import__('telegram_prisms.core', fromlist=['_Bucket'])"
           "._Bucket(tokens=1e9, capacity=1e9, refill_per_sec=1e9)\n"
           "p = MessagePrism(TelegramHTTP('123:test', transport=_T(), "
           "limiter=rl, sleep_fn=lambda s: None), events=EventEmitter())"),
          number=20000)

    print("\nDone. (Timings are machine-dependent; run on target hardware.)")


if __name__ == "__main__":
    main()