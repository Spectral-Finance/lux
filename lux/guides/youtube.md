# YouTube Integration Guide

Lux supports YouTube Data API v3 and Live Streaming API for channel management and live streaming automation.

## Configuration

```elixir
config :lux, :api_keys,
  youtube_api_key: "YOUR_API_KEY",
  youtube_client_id: "YOUR_CLIENT_ID",
  youtube_client_secret: "YOUR_CLIENT_SECRET",
  youtube_refresh_token: "YOUR_REFRESH_TOKEN"
```

## OAuth2 Token Refresh

```elixir
{:ok, token} = Lux.Integrations.YouTube.Client.refresh_access_token()
```

## Search Videos

```elixir
Lux.Lenses.YouTube.SearchVideos.focus(%{query: "elixir", max_results: 5})
```

## Get Video Details

```elixir
Lux.Lenses.YouTube.GetVideo.focus(%{video_id: "VIDEO_ID"})
```

## Get Channel Details

```elixir
Lux.Lenses.YouTube.GetChannel.focus(%{channel_id: "CHANNEL_ID"})
```

## Live Chat Monitoring

```elixir
Lux.Lenses.YouTube.GetLiveChat.focus(%{
  live_chat_id: "CHAT_ID",
  access_token: token
})
```

## Stream Health Monitoring

```elixir
Lux.Lenses.YouTube.GetStreamHealth.focus(%{
  broadcast_id: "BROADCAST_ID",
  access_token: token
})
```

## Create Live Stream

```elixir
Lux.Prisms.YouTube.ManageStream.handler(%{
  action: "create",
  title: "My Live Stream",
  access_token: token
}, %{})
```

## Create Live Broadcast

```elixir
Lux.Prisms.YouTube.ManageBroadcast.handler(%{
  action: "create",
  title: "My Broadcast",
  scheduled_start: "2026-01-01T12:00:00Z",
  access_token: token
}, %{})
```

## Transition Broadcast

```elixir
Lux.Prisms.YouTube.ManageBroadcast.handler(%{
  action: "transition",
  broadcast_id: "BROADCAST_ID",
  broadcast_status: "live",
  access_token: token
}, %{})
```

## Send Chat Message

```elixir
Lux.Prisms.YouTube.SendChatMessage.handler(%{
  live_chat_id: "CHAT_ID",
  message: "Hello YouTube!",
  access_token: token
}, %{})
```

## Upload Video (Metadata + Resumable Upload)

```elixir
Lux.Prisms.YouTube.UploadVideo.handler(%{
  title: "My Video",
  description: "Demo",
  file_path: "/path/to/video.mp4",
  access_token: token
}, %{})
```

> Note: The actual binary upload can be handled with the resumable upload URL returned by YouTube.
