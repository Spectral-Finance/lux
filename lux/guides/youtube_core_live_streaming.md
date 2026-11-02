# YouTube Core Integration and Live Streaming in Lux

The YouTube Core Integration and Live Streaming subsystem equips autonomous Lux agents with full control over the YouTube Data API v3 and live streaming infrastructure.

Agents can authenticate via OAuth 2.0, perform chunked resumable video uploads, schedule and manage broadcast lifecycles, monitor RTMP ingestion health in real-time, interact dynamically in live chat, handle Super Chat donations, and execute automated multi-stream failovers.

---

## Architecture Overview

The system is organized modularly under `Lux.YouTube.LiveStreaming`:

```
Lux.YouTube.LiveStreaming
├── OAuthManager           # Google OAuth 2.0 token exchange, refresh rotation, and auth headers
├── VideoManager           # Resumable chunked video uploads and metadata lifecycle
├── BroadcastManager       # LiveBroadcast & LiveStream creation, RTMP binding, and state transitions
├── HealthMonitor          # Ingestion telemetry, bitrate drops, FPS tracking, and audio verification
├── ChatManager            # Real-time live chat polling, Super Chat alerts, and automated moderation
└── MultiStreamController  # Primary/backup failover and ingestion quality control
```

A first-class agent prism (`Lux.Prisms.YouTubeLiveStreamingPrism`) exposes all capabilities to Lux agents and company workflows.

---

## 1. Unified Automated Stream Setup (`Lux.YouTube.LiveStreaming`)

Initialize and prepare an automated live broadcast with a single call:

```elixir
alias Lux.YouTube.LiveStreaming

params = %{
  title: "Lux 24/7 Autonomous AI Agent Swarm",
  description: "Live demonstration of multi-agent collaboration running on Elixir OTP",
  resolution: :res_1080p,
  frame_rate: :fps_60,
  latency_preference: :ultra_low,
  enable_dvr: true
}

{:ok, stream_session} = LiveStreaming.setup_automated_stream(params)

stream_session.rtmp_url             #=> "rtmp://a.rtmp.youtube.com/live2"
stream_session.stream_key           #=> "lux-live-key-..."
stream_session.broadcast.status     #=> :ready
stream_session.initial_health       #=> %{health_status: :good, ...}
```

---

## 2. OAuth 2.0 Authentication & Token Lifecycle (`OAuthManager`)

Generate consent URLs, exchange authorization codes, and automatically rotate expired tokens:

```elixir
alias Lux.YouTube.LiveStreaming.OAuthManager

# Generate authorization URL
auth_url = OAuthManager.generate_auth_url(
  "GOOGLE_CLIENT_ID",
  "https://myagent.network/oauth/callback"
)

# Exchange auth code for token bundle
{:ok, tokens} = OAuthManager.exchange_code_for_tokens(
  "auth_code_from_callback",
  "GOOGLE_CLIENT_ID",
  "GOOGLE_CLIENT_SECRET",
  "https://myagent.network/oauth/callback"
)

# Check expiration and rotate
if OAuthManager.token_expired?(tokens) do
  {:ok, new_tokens} = OAuthManager.refresh_access_token(
    tokens.refresh_token,
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET"
  )
end
```

---

## 3. Resumable Chunked Video Uploads (`VideoManager`)

Handles reliable uploading of large video binaries using YouTube's resumable upload protocol:

```elixir
alias Lux.YouTube.LiveStreaming.VideoManager

metadata = %{
  title: "Building Distributed Multi-Agent Systems in Elixir",
  description: "Comprehensive tutorial on Lux framework",
  tags: ["elixir", "lux", "ai-agents"],
  category_id: "28", # Science & Technology
  privacy_status: :public,
  made_for_kids: false
}

# 1. Initiate upload session
{:ok, session} = VideoManager.initiate_resumable_upload(metadata, 100 * 1024 * 1024)

# 2. Upload in 8MB chunks
{:ok, updated_session} = VideoManager.upload_chunk(session, chunk_binary)

# 3. Check status
updated_session.status  #=> :uploading or :completed
```

---

## 4. Live Broadcast State Transitions (`BroadcastManager`)

Transitions YouTube broadcasts through the mandatory lifecycle:

```
:ready ──▶ :testing ──▶ :live ──▶ :complete
```

```elixir
alias Lux.YouTube.LiveStreaming.BroadcastManager

# Transition to testing mode
{:ok, testing_broadcast} = BroadcastManager.transition_broadcast(broadcast, :testing)

# When ready, transition to live
{:ok, live_broadcast} = BroadcastManager.transition_broadcast(testing_broadcast, :live)

# End broadcast
{:ok, ended_broadcast} = BroadcastManager.transition_broadcast(live_broadcast, :complete)
```

---

## 5. Ingestion Stream Health Monitoring (`HealthMonitor`)

Monitors RTMP stream bandwidth and frame stability to detect packet loss before viewers notice:

```elixir
alias Lux.YouTube.LiveStreaming.HealthMonitor

report = HealthMonitor.evaluate_health(stream_id, %{
  bitrate_kbps: 6200,
  fps: 60.0,
  target_bitrate_kbps: 6000,
  audio_healthy: true
})

report.health_status    #=> :good
report.is_stream_stable #=> true
```

---

## 6. Real-Time Chat & Super Chat Moderation (`ChatManager`)

Polls live chat, highlights financial donations, and triggers automated replies:

```elixir
alias Lux.YouTube.LiveStreaming.ChatManager

# Process incoming chat batch
result = ChatManager.process_chat_batch([
  %{author: "Viewer1", text: "Where can I find the code?", super_chat_usd: 0.0},
  %{author: "Supporter2", text: "Keep up the great work!", super_chat_usd: 50.0}
])

# Automated Super Chat thank-you
sc = List.first(result.super_chats)
reply = ChatManager.generate_chat_response(sc)
#=> "🎉 Massive thank you to Supporter2 for the $50.0 Super Chat!..."
```

---

## 7. Autonomous Agent Prism Integration

Embed `YouTubeLiveStreamingPrism` directly into autonomous agents:

```elixir
defmodule MyApp.Agents.YouTubeStreamBroadcasterAgent do
  use Lux.Agent,
    name: "YouTube Stream Broadcaster",
    description: "Orchestrates live broadcasts, monitors stream health, and moderates live chat",
    prisms: [Lux.Prisms.YouTubeLiveStreamingPrism]
end
```

Or execute dynamically:

```elixir
alias Lux.Prisms.YouTubeLiveStreamingPrism

{:ok, response} = YouTubeLiveStreamingPrism.run(%{
  action: "create_broadcast",
  payload: %{title: "Lux Live Demo"}
})

assert response.result.rtmp_ingestion_url != nil
```
