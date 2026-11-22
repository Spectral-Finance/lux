# discord_prisms — Discord Core Prisms, Lenses and Beams

Implementation for **Spectral-Finance/lux issue #57** ($2,000 bounty).

A dependency-free (stdlib-only) package providing the four Discord prisms
required by the issue, built on a shared production-grade core with rate
limiting, retry/backoff, event emission, and pluggable persistence.

## Installation

```bash
# Drop into the lux monorepo (no third-party deps required)
cp -r discord_prisms <lux-repo>/python/discord_prisms/
```

Or import directly by adding this directory to `PYTHONPATH`.

## Quick start

```python
from discord_prisms import (
    DiscordHTTP, EventEmitter, InMemoryPersistence,
    MessageManagementPrism, ChannelManagementPrism,
    ModerationPrism, EventHandlingPrism,
)

http = DiscordHTTP(token="BOT_TOKEN")
events = EventEmitter()
store = InMemoryPersistence()

messages = MessageManagementPrism(http, events=events)
channels = ChannelManagementPrism(http, events=events)
moderation = ModerationPrism(http, events=events, banned_words=["spam"])
event_handling = EventHandlingPrism(http, events=events, persistence=store)

# Every operation emits a structured event:
events.on("MessageManagement.message_created", lambda **kw: print(kw))

messages.create_message("CHANNEL_ID", "Hello from lux!")
```

## Prisms

### MessageManagementPrism ($600)
- `create_message(channel_id, content, tts=False, embeds=None)`
- `edit_message(channel_id, message_id, content, embeds=None)`
- `delete_message(channel_id, message_id, reason=None)`
- `bulk_delete(channel_id, message_ids, reason=None)` — enforces Discord's 2–100 ID rule
- `get_history(channel_id, limit=50, before=None, after=None)`

### ChannelManagementPrism ($500)
- `create_channel(guild_id, name, channel_type=0, topic=None, permission_overwrites=None, parent_id=None)`
- `update_channel(channel_id, **fields)`
- `delete_channel(channel_id, reason=None)`
- `set_permissions(channel_id, overwrite_id, allow=0, deny=0, permission_type=0)`
- `archive_channel(channel_id, reason=None)` / `unarchive_channel(channel_id, reason=None)`

### ModerationPrism ($500)
- `filter_content(content)` — banned-word content filter (no API call)
- `timeout_member(guild_id, member_id, duration_seconds, reason=None)` — ISO8601 duration
- `ban_member(guild_id, user_id, delete_message_seconds=0, reason=None)`
- `unban_member(guild_id, user_id, reason=None)`
- `add_warning(guild_id, user_id, reason, moderator_id=None)` / `get_warnings(...)` / `clear_warnings(...)`

### EventHandlingPrism ($400)
- `schedule_event(guild_id, name, scheduled_start_time, entity_type=3, channel_id=None, description=None)`
- `add_reminder(event_id, remind_at_epoch, channel_id=None, message=None)`
- `due_reminders(now_epoch=None)` — returns due, unsent reminders
- `notify(channel_id, message)` — send an event notification
- `delete_event(guild_id, event_id)`

## Core features (acceptance criteria)

| Requirement | Implementation |
|---|---|
| Rate limiting | `RateLimiter` — per-route token bucket, syncs from `X-RateLimit-*` headers, pauses on 429 `Retry-After` |
| Retry mechanisms | `DiscordHTTP` — exponential backoff + jitter for 429/5xx, honours `Retry-After` |
| Event emission | `EventEmitter` — sync pub/sub; every prism operation emits `<Prism>.<action>` |
| State persistence | `InMemoryPersistence` (default) / `JsonFilePersistence` (durable) |
| Error handling | Typed exceptions: `NotFound` (404), `Forbidden` (403), `RateLimited` (429), `Server` (5xx), `DiscordAPIError` |

## Testing

```bash
python3 -m pytest test_prisms.py -v
# or (stdlib-only fallback):
python3 test_prisms.py
```

18 unit tests cover all four prisms, rate-limit retry, error mapping, event
emission, and persistence — all using an injected fake transport (no network).

## License

Same as the lux repository (MIT).