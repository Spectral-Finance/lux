# YouTube Core Integration and Live Streaming

Lux provides a comprehensive YouTube Data API v3 and YouTube Live Streaming integration (`Lux.Integrations.YouTube` and `Lux.Prisms.YouTube.CorePrism`) enabling autonomous agents to manage YouTube channels, upload videos, orchestrate live broadcasts, monitor encoder telemetry, and interact with real-time live chat.

## Core Capabilities

1. **OAuth2 Authentication & Token Refresh**: Manages Google OAuth2 client credentials, scopes, and automatic token refresh (`configure_oauth2/1`, `refresh_access_token/1`).
2. **Channel, Video & Playlist Management**: Uploads and updates videos (`upload_video/1`, `update_video/2`), manages playlists (`create_playlist/1`), and queries channel analytics (`get_channel/1`).
3. **Live Stream & Broadcast Orchestration**: Creates RTMP/HLS ingestion streams (`720p30`, `1080p30`, `1080p60`, `1440p60`, `4k60`), schedules broadcasts, binds streams, and automates transitions (`:created` -> `:ready` -> `:testing` -> `:live` -> `:complete`, plus `:auto_live`).
4. **Stream Health & Multi-Quality Control**: Monitors ingest bitrate, frame rate, and dropped frames (`check_stream_health/2`) and recommends quality profile downgrades during network congestion.
5. **Real-Time LiveChat & Quota Management**: Polls and sends live chat messages, moderates spam/users (`:delete_message`, `:timeout_user`, `:ban_user`), and tracks daily YouTube Data API v3 quota units (`get_quota_status/0`).

## Usage Example

```elixir
alias Lux.Integrations.YouTube

# 1. Authenticate via OAuth2
{:ok, _session} = YouTube.configure_oauth2(%{
  client_id: "your-client-id.apps.googleusercontent.com",
  refresh_token: "1//your-refresh-token"
})

# 2. Provision a 1080p60 RTMP stream, schedule a broadcast, bind, and transition to live
{:ok, stream} = YouTube.create_live_stream(%{title: "Agent Main Feed", quality_profile: "1080p60"})
{:ok, broadcast} = YouTube.create_live_broadcast(%{title: "Lux Autonomous Live Stream", latency_preference: "ultraLow"})
{:ok, _} = YouTube.bind_broadcast_to_stream(broadcast.broadcast_id, stream.stream_id)
{:ok, live} = YouTube.transition_broadcast(broadcast.broadcast_id, :auto_live)

# 3. Interact with LiveChat and monitor stream health
{:ok, _msg} = YouTube.send_chat_message(live.live_chat_id, "We are live!")
{:ok, chat_page} = YouTube.poll_chat_messages(live.live_chat_id)
{:ok, health} = YouTube.check_stream_health(stream.stream_id)
```
