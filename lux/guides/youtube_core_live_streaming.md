# YouTube Core Integration and Live Streaming

This guide shows the credential boundary for planning YouTube Data API v3 and live-streaming operations in Lux.

The YouTube live workflow is intentionally dry-run first. Agents can build an auditable plan for OAuth, upload, live broadcast setup, stream binding, live chat monitoring, health checks, and broadcast transitions without requiring real channel credentials in tests.

```elixir
alias Lux.Integrations.YouTube.LiveStreaming

{:ok, workflow} =
  LiveStreaming.plan_broadcast_workflow(%{
    title: "Lux market briefing",
    scheduled_start_time: "2026-06-06T12:00:00Z",
    privacy_status: "unlisted",
    broadcast_id: "broadcast-1",
    stream_id: "stream-1",
    live_chat_id: "chat-1",
    target_life_cycle_status: "testing"
  })
```

The returned workflow includes request envelopes for:

- OAuth authorization, token exchange, and refresh.
- `channels.list` for channel validation.
- `videos.insert` resumable upload startup.
- `liveBroadcasts.insert`, `liveStreams.insert`, and `liveBroadcasts.bind`.
- `liveChat/messages` polling and safe chat message drafting.
- `liveStreams.list` health polling.
- `liveBroadcasts.transition` with lifecycle guardrails.

Live side effects are not executed by the planner. A credentialed adapter must supply OAuth tokens, review moderation and transition guardrails, then explicitly execute the selected request envelopes.
