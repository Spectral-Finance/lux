# YouTube Data API Integration

Lux includes a small, mockable YouTube Data API v3 client for channel management,
video upload initiation, live stream setup, live chat interaction, and stream
health checks.

## Configuration

Create a Google OAuth client and request the default YouTube scopes:

```elixir
Lux.Integrations.YouTube.default_scopes()
```

Build a consent URL:

```elixir
Lux.Integrations.YouTube.authorization_url(
  client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
  redirect_uri: "https://example.com/oauth/youtube/callback",
  state: "csrf-token"
)
```

After exchanging the authorization code, configure the access token:

```bash
export YOUTUBE_ACCESS_TOKEN="ya29..."
```

## Channel Management

```elixir
Lux.Integrations.YouTube.Client.list_channels()
```

## Resumable Uploads

```elixir
metadata = %{
  snippet: %{title: "Launch demo", description: "Lux managed upload"},
  status: %{privacyStatus: "private"}
}

{:ok, %{"location" => upload_url}} =
  Lux.Integrations.YouTube.Client.initiate_resumable_upload(metadata)
```

The returned `location` is the Google resumable upload session URL. The caller
can stream the media bytes to that URL according to the YouTube upload protocol.

Agents can also start an upload through the prism interface:

```elixir
Lux.Prisms.YouTube.Videos.InitiateResumableUpload.handler(
  %{title: "Launch demo", privacy_status: "private"},
  %{name: "Publisher"}
)
```

## Live Streaming

```elixir
{:ok, broadcast} =
  Lux.Integrations.YouTube.Client.insert_live_broadcast(%{
    snippet: %{title: "Product launch", scheduledStartTime: "2026-05-13T12:00:00Z"},
    status: %{privacyStatus: "unlisted"},
    contentDetails: %{enableAutoStart: true, enableAutoStop: true}
  })

{:ok, stream} =
  Lux.Integrations.YouTube.Client.insert_live_stream(%{
    snippet: %{title: "Primary ingest"},
    cdn: %{frameRate: "30fps", ingestionType: "rtmp", resolution: "1080p"}
  })

Lux.Integrations.YouTube.Client.bind_live_broadcast(broadcast["id"], stream["id"])
Lux.Integrations.YouTube.Client.transition_live_broadcast(broadcast["id"], "live")
Lux.Integrations.YouTube.Client.list_stream_health(stream["id"])
```

The same workflow is available as agent-callable prisms:

```elixir
Lux.Prisms.YouTube.Live.CreateBroadcast.handler(%{
  title: "Product launch",
  scheduled_start_time: "2026-05-13T12:00:00Z",
  privacy_status: "unlisted"
}, %{name: "Producer"})

Lux.Prisms.YouTube.Live.CreateStream.handler(%{title: "Primary ingest"}, %{name: "Producer"})

Lux.Prisms.YouTube.Live.BindBroadcast.handler(%{
  broadcast_id: "broadcast-id",
  stream_id: "stream-id"
}, %{name: "Producer"})

Lux.Prisms.YouTube.Live.TransitionBroadcast.handler(%{
  broadcast_id: "broadcast-id",
  status: "live"
}, %{name: "Producer"})
```

## Live Chat

```elixir
Lux.Integrations.YouTube.Client.list_live_chat_messages("live-chat-id")
Lux.Integrations.YouTube.Client.insert_live_chat_message("live-chat-id", "Hello from Lux")

Lux.Prisms.YouTube.Live.SendChatMessage.handler(
  %{live_chat_id: "live-chat-id", text: "Hello from Lux"},
  %{name: "Moderator"}
)
```

## Error Handling

The client normalizes common API failures:

- `{:error, :invalid_token}` for 401 responses
- `{:error, {:rate_limited, message, errors}}` for 403/429 quota responses
- `{:error, {status, message_or_body}}` for other API errors
