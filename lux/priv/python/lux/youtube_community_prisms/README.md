# youtube_community_prisms

**YouTube Community Management & Engagement prisms for [Spectral-Finance/lux](https://github.com/Spectral-Finance/lux) — issue [#70](https://github.com/Spectral-Finance/lux/issues/70) ($2,000 bounty).**

A production-grade, **standard-library-only** Python implementation of the five
community-management prisms required by issue #70. It drops into the lux
monorepo (`lux/priv/python/lux/`) without adding any transitive dependency and
mirrors the Elixir `use Lux.Prism` handler contract
(`handler(input, ctx) -> {:ok, _} | {:error, _}`).

---

## Prism classes

### Primary prisms

| Prism | Responsibility |
|-------|----------------|
| `CommunityPostPrism` | Community post scheduling, publishing, queue/due processing, cancellation |
| `CommentModerationPrism` | Comment listing, sentiment analysis, spam detection, moderation status, automated replies |
| `LiveChatPrism` | Live chat listing, spam moderation/deletion, user bans, slow-mode, chat log |
| `MemberManagementPrism` | Subscriber/member interaction tracking, fan segmentation, interaction patterns |
| `AnalyticsPrism` | Engagement analytics, sentiment aggregation, campaign management, reporting |

### Spec-mandated class names (issue #70 "Required class names & file paths")

The issue's acceptance criteria name the exact classes the lux monorepo expects.
These are provided in `community.py` and re-exported from the package root:

| Class | Responsibility |
|-------|----------------|
| `CommentManagementPrism` | `commentThreads`/`comments` read + moderation (list/get/post/update/delete, setModerationStatus) |
| `ResponseGenerationPrism` | Automated reply generation (single + batch) and posting via `comments.insert` |
| `SentimentAnalysisPrism` | Sentiment scoring over text, comments, threads, and batches |
| `SpamModerationPrism` | Spam detection + threshold-based moderation (hold/approve/reject) |
| `CommunityPostSchedulerPrism` | Community post scheduling, queue, due-processing, cancellation |
| `EngagementCampaignPrism` | Engagement campaign create/track/report/close |
| `CommentThreadsLens` | Read lens over `commentThreads.list` with normalisation |
| `CommunityManagementBeam` | Orchestration beam: end-to-end triage (fetch → analyse → moderate) |

Every prism shares one infrastructure core (`core.py`) providing:

- **Rate limiting** — per-route token buckets + daily-quota accounting
  (`search.list` = 100 units, most others = 1), 429/quota aware.
- **Retry with backoff** — exponential backoff + jitter for 429/5xx, honours
  `Retry-After`.
- **Event emission** — a synchronous `EventEmitter` so every operation emits a
  structured `<Prism>.<event>` event.
- **Persistence** — pluggable store (`InMemoryPersistence` default,
  `JsonFilePersistence` for durable state).
- **Typed errors** — `YouTubeAPIError` hierarchy: `ValidationError`,
  `AuthenticationError`, `NotFoundError`, `ForbiddenError`, `RateLimitedError`,
  `ServerError`.

Text analysis (`analysis.py`) is deterministic and dependency-free: lexicon-based
**sentiment analysis** (with negation handling + emoji cues), a rule-based
**spam detector**, and template-driven **response generation**.

---

## Installation / drop-in

```bash
# Copy the package into the lux Python tree (no deps to install):
cp -r youtube_community_prisms \
      /path/to/lux/lux/priv/python/lux/youtube_community_prisms
```

Requires Python 3.8+ (uses only the standard library).

---

## Quick start

```python
from youtube_community_prisms import (
    YouTubeHTTP, EventEmitter,
    CommunityPostPrism, CommentModerationPrism, LiveChatPrism,
    MemberManagementPrism, AnalyticsPrism,
)

# 1. Shared HTTP core (API key or OAuth bearer token).
http = YouTubeHTTP(api_key="YOUR_YOUTUBE_API_KEY")   # or oauth=True for OAuth2

# 2. Shared event bus — subscribe to any prism event.
events = EventEmitter()
events.on("CommentModeration.moderation_status_set",
          lambda event, **kw: print("moderated:", kw))

# 3. Build prisms.
posts     = CommunityPostPrism(http, events=events)
comments  = CommentModerationPrism(http, events=events, auto_hold_threshold=0.5)
live      = LiveChatPrism(http, events=events)
members   = MemberManagementPrism(http, events=events)
analytics = AnalyticsPrism(http, events=events)
```

### Schedule & publish a community post

```python
# Schedule for later (persisted; publish via process_due_posts()).
post = posts.schedule_post("UCxxxx", "New tutorial drops Friday! 🚀",
                           scheduled_for=1_700_000_000)
print(post["id"], post["status"])          # -> post_... scheduled

# Publish every due post now (optionally via an injected publisher).
posts.process_due_posts()
```

### Moderate comments with sentiment + spam detection

```python
# List comment threads for a video.
data = comments.list_comment_threads(video_id="dQw4w9WgXcQ", max_results=50)

# Analyse + auto-moderate a single comment body.
result = comments.moderate_comment(
    "UgxK1commentId", "BUY NOW!!! click here https://spam.example make money")
print(result["decision"])                   # -> "held"  (spam above threshold)

# Generate and post a reply to a genuine question.
comments.auto_reply("UgxAnotherId", "How do I set up the API key?")
```

### Live chat moderation

```python
live.set_slow_mode("live_chat_id", slow_mode_seconds=15)
for msg in live.list_messages("live_chat_id")["items"]:
    live.moderate_message("live_chat_id", msg["id"],
                          text=msg["snippet"]["displayMessage"])
live.ban_user("live_chat_id", "UCxxxx", "UCtroll", ban_duration_seconds=600)
```

### Track members & analyse engagement

```python
members.record_interaction("UCxxxx", "UCfan1", "comment", weight=3.0)
segments = members.segment_members("UCxxxx")   # -> {"active": [...], "engaged": [...], "new": [...]}

threads = comments.list_comment_threads(video_id="VIDEO")["items"]
report = analytics.report(threads=threads, channel_id="UCxxxx")
print(report["engagement"]["engagement_rate"], report["sentiment"]["percentages"])
```

### Engagement campaigns

```python
camp = analytics.create_campaign("Q4 Growth", "UCxxxx", goals={"subs": 1000})
analytics.record_campaign_metric(camp["id"], "new_subs", 250)
print(analytics.campaign_report(camp["id"])["metrics"]["new_subs"]["sum"])
analytics.close_campaign(camp["id"])
```

### Lux-compatible handler contract

Every prism exposes `handler(action, params, ctx)` returning
`{"ok": True, "data": ...}` or `{"ok": False, "error": {...}}` — the Python
analogue of Elixir's `{:ok, _} | {:error, _}`:

```python
resp = comments.handler("hold_for_review", {"comment_id": "Ugx123"})
assert resp["ok"] is True
```

---

## Testing

The suite is fully offline (injected fake transport — **no network calls**):

```bash
cd youtube_community_prisms
python3 -m pytest test_prisms.py -v
# 33 passed
```

A stdlib-only fallback runner is also provided:

```bash
python3 test_prisms.py
```

Coverage includes: sentiment (positive/negative/neutral/negation), spam
detection, response generation, post scheduling/due/publish/cancel, comment
listing + moderation + auto-reply, live-chat moderation/bans/slow-mode, member
segmentation, analytics + campaign lifecycle, 429 retry, daily-quota
accounting, 404/403/400 error mapping, quota-exceeded mapping, event emission,
persistence, and the Lux handler contract.

---

## Project layout

```
youtube_community_prisms/
├── README.md
├── test_prisms.py                     # 33 offline tests
└── youtube_community_prisms/
    ├── __init__.py                    # public API
    ├── core.py                        # rate limiter, retry, events, persistence, errors, HTTP, Prism base
    ├── analysis.py                    # sentiment, spam, response generation
    └── prisms.py                      # the 5 prisms
```

---

## Error handling

All failures raise a typed `YouTubeAPIError` subclass carrying `.status`,
`.payload` and a machine-readable `.code`:

| Exception | HTTP | Meaning |
|-----------|------|---------|
| `ValidationError` | 400 | Malformed request / failed local validation |
| `AuthenticationError` | 401 | Missing/invalid API key or OAuth scope |
| `ForbiddenError` | 403 | Authenticated user lacks permission |
| `NotFoundError` | 404 | Resource does not exist / not visible |
| `RateLimitedError` | 429 | Rate limit or daily quota exceeded (`.retry_after`) |
| `ServerError` | 5xx | Transient YouTube-side failure |

---

## License

MIT — same as the lux monorepo.