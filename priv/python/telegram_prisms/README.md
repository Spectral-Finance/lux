# telegram_prisms — Telegram Core API Integration

Implementation for **Spectral-Finance/lux issue #62** ($2,500 bounty).

A dependency-free (stdlib-only) package providing the complete Telegram Bot API
lens, built on a shared production-grade core with rate limiting, retry/backoff,
event emission, secure token management, and pluggable persistence.

## Installation

```bash
# Drop into the lux monorepo (no third-party deps required)
cp -r telegram_prisms <lux-repo>/python/telegram_prisms/
```

Or import directly by adding this directory to `PYTHONPATH`.

## Quick start

```python
from telegram_prisms import (
    TelegramHTTP, TokenManager, EventEmitter, InMemoryPersistence,
    BotPrism, MessagePrism, MediaPrism,
    KeyboardPrism, WebhookPrism, UpdatePrism,
)

# Secure token management (never logged; maskable; rotatable)
tokens = TokenManager()  # reads TELEGRAM_BOT_TOKEN env var, or pass token=...
http = TelegramHTTP(tokens)
events = EventEmitter()
store = InMemoryPersistence()

bot = BotPrism(http, events=events)
messages = MessagePrism(http, events=events)
media = MediaPrism(http, events=events)
keyboards = KeyboardPrism(http, events=events)
webhook = WebhookPrism(http, events=events)
updates = UpdatePrism(http, events=events, persistence=store)

# Every operation emits a structured event:
events.on("Message.message_sent", lambda **kw: print(kw))

# Authenticate (validates the token)
me = bot.get_me()
print("Logged in as", me["username"])

# Send a message with an inline keyboard
kb = KeyboardPrism.inline_keyboard([
    [KeyboardPrism.inline_button("Click me", callback_data="btn:1")],
])
messages.send_message(chat_id, "Hello from lux!", reply_markup=kb)

# Dispatch updates to handlers
@updates.on_message
def handle(update):
    text = update["message"].get("text", "")
    messages.reply(update["message"]["chat"]["id"],
                   update["message"]["message_id"], f"Echo: {text}")

updates.poll(timeout=30)
```

## Prisms

### BotPrism — authentication & bot management
- `get_me()` / `whoami()` — validate token, return bot user object
- `get_my_name()` — convenience accessor
- `get_my_commands()` / `set_my_commands(commands)` / `delete_my_commands()`
- `log_out()` / `close()` — revoke token / close session

### MessagePrism — text message handling
- `send_message(chat_id, text, *, parse_mode=None, disable_web_page_preview=False, disable_notification=False, reply_to_message_id=None, reply_markup=None, entities=None, message_thread_id=None)`
- `reply(chat_id, message_id, text, **kwargs)` — reply to a specific message
- `edit_message_text(chat_id, message_id, text, *, parse_mode=None, reply_markup=None, inline_message_id=None)`
- `edit_message_reply_markup(chat_id, message_id, *, reply_markup=None, inline_message_id=None)`
- `delete_message(chat_id, message_id)`
- `forward_message(chat_id, from_chat_id, message_id, *, disable_notification=False)`
- `copy_message(chat_id, from_chat_id, message_id, *, disable_notification=False)`

### MediaPrism — photos / documents / voice / video / audio
- `send_photo(chat_id, photo, *, caption=None, parse_mode=None, ...)`
- `send_document(chat_id, document, *, caption=None, ...)`
- `send_voice(chat_id, voice, *, caption=None, duration=None, ...)`
- `send_audio(chat_id, audio, *, caption=None, duration=None, ...)`
- `send_video(chat_id, video, *, caption=None, duration=None, ...)`

`photo`/`document`/etc. may be a **file_id / URL string** (sent as JSON) or
**raw `bytes`** (uploaded as `multipart/form-data`).

### KeyboardPrism — inline + custom keyboards
- `inline_button(text, **kwargs)` — build one inline button
- `inline_keyboard(rows)` — build an inline keyboard markup
- `reply_keyboard(rows, *, resize_keyboard=True, one_time_keyboard=False, selective=False)` — custom reply keyboard
- `remove_reply_keyboard(selective=False)` — remove a custom keyboard
- `answer_callback_query(callback_query_id, *, text=None, show_alert=False, url=None, cache_time=0)`
- `set_chat_menu_button(chat_id=None, menu_button=None)`

### WebhookPrism — webhook + updates handling
- `set_webhook(url, *, secret_token=None, certificate=None, allowed_updates=None, drop_pending_updates=False, max_connections=None)`
- `delete_webhook(*, drop_pending_updates=False)`
- `get_webhook_info()`
- `get_updates(*, offset=None, limit=None, timeout=0, allowed_updates=None)`

### UpdatePrism — high-level update dispatch
- `register(update_type, handler)` / `on_message(handler)` / `on_callback_query(handler)` / `on_edited_message(handler)`
- `classify(update)` — return the primary update type key
- `process_update(update)` — route one update to matching handlers
- `process_updates(updates)` — process a batch, advance offset
- `poll(*, timeout=0, limit=None)` — long-poll + dispatch

## Core features (issue #62 acceptance criteria)

| Requirement | Implementation |
|---|---|
| Complete Telegram Bot API lens | Six prisms: `BotPrism`, `MessagePrism`, `MediaPrism`, `KeyboardPrism`, `WebhookPrism`, `UpdatePrism` |
| Secure token management | `TokenManager` — masks token in `repr`/`str`, supports env/file/explicit sources, runtime rotation |
| Comprehensive error handling + retries | `TelegramHTTP` — exponential backoff + jitter for 429/5xx, honours `parameters.retry_after`; typed exceptions |
| Rate limit handling + queueing | `RateLimiter` — per-method token bucket, pauses on 429 `retry_after`, thread-safe |
| Documentation + examples | This README + inline docstrings + `bench.py` |
| Test coverage > 90% | 38 unit tests, all paths via injected fake transport (no network) |
| Performance benchmarks | `bench.py` — stdlib `timeit` benchmarks of hot paths |

### Typed exceptions
- `TelegramAPIError` — base (mirrors Telegram's `{"ok": false, "error_code", "description"}`)
- `NotFoundError` (404) — resource not found
- `ForbiddenError` (403) — bot blocked / lacks permission
- `RateLimitedError` (429) — carries `retry_after`
- `ServerError` (5xx) — Telegram-side transient failure

## Testing

```bash
python3 -m pytest test_prisms.py -v
# or (stdlib-only fallback):
python3 test_prisms.py
```

38 unit tests cover all six prisms, rate-limit retry (429 `parameters.retry_after`),
error mapping (404/403/400/5xx), token manager (masking/rotation/env/file),
event emission, persistence, and update dispatch — all using an injected fake
transport (no network).

## Benchmarks

```bash
python3 bench.py
```

Stdlib `timeit` benchmarks of the hot paths (JSON envelope decode, multipart
encoding, rate-limiter acquire, full prism call).

## License

Same as the lux repository (MIT).