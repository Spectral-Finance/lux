# YouTube Integration Guide

Lux provides YouTube OAuth, Data API v3, resumable upload, and live-streaming
helpers that are safe to call from agents with runtime credentials. Pass the
current OAuth access token into each request instead of relying on a static
application token.

## OAuth

Exchange an authorization code, persist the returned refresh token in your own
credential store, then refresh access tokens before downstream work:

```elixir
alias Lux.Integrations.YouTube.Client

{:ok, token} =
  Client.exchange_code(%{
    client_id: System.fetch_env!("YOUTUBE_CLIENT_ID"),
    client_secret: System.fetch_env!("YOUTUBE_CLIENT_SECRET"),
    code: authorization_code,
    redirect_uri: "https://example.com/oauth/youtube/callback"
  })

{:ok, refreshed} =
  Client.refresh_access_token(%{
    client_id: System.fetch_env!("YOUTUBE_CLIENT_ID"),
    client_secret: System.fetch_env!("YOUTUBE_CLIENT_SECRET"),
    refresh_token: token["refresh_token"]
  })
```

## Data API Reads

Lenses accept atom or string keys, making them easy to call from Elixir code or
JSON-style agent input:

```elixir
alias Lux.Lenses.YouTube.Channels.GetChannel
alias Lux.Lenses.YouTube.Videos.GetVideo

{:ok, channel} =
  GetChannel.focus(%{
    "access_token" => refreshed["access_token"],
    "mine" => true
  })

{:ok, video} =
  GetVideo.focus(%{
    access_token: refreshed["access_token"],
    id: "VIDEO_ID"
  })
```

## Resumable Uploads

Start a resumable session, upload bytes, and query progress if the upload is
interrupted:

```elixir
alias Lux.Integrations.YouTube.Client

metadata = %{
  snippet: %{title: "Launch demo", description: "Created from Lux"},
  status: %{privacyStatus: "private"}
}

{:ok, %{session_url: session_url}} =
  Client.start_resumable_upload(metadata, %{
    access_token: refreshed["access_token"],
    content_type: "video/mp4",
    content_length: byte_size(video_bytes)
  })

{:ok, %{"id" => video_id}} =
  Client.complete_resumable_upload(session_url, video_bytes, %{
    access_token: refreshed["access_token"],
    content_type: "video/mp4"
  })

{:ok, status} =
  Client.upload_status(session_url, %{
    access_token: refreshed["access_token"],
    total_size: byte_size(video_bytes)
  })
```

The prism equivalents are
`Lux.Prisms.YouTube.Videos.StartResumableUpload`,
`Lux.Prisms.YouTube.Videos.CompleteResumableUpload`, and
`Lux.Prisms.YouTube.Videos.GetUploadStatus`.

## Live Streaming

The live workflow creates a broadcast, creates a stream, binds them, and keeps
state transitions explicit:

```elixir
alias Lux.Integrations.YouTube.LiveWorkflow

{:ok, %{broadcast: broadcast, stream: stream}} =
  LiveWorkflow.schedule(%{
    access_token: refreshed["access_token"],
    title: "Product launch",
    scheduled_start_time: "2026-06-02T12:00:00Z",
    privacy_status: "private"
  })

{:ok, _} =
  LiveWorkflow.transition_broadcast(
    broadcast["id"],
    "ready",
    "testing",
    access_token: refreshed["access_token"]
  )

{:ok, _} =
  LiveWorkflow.transition_broadcast(
    broadcast["id"],
    "testing",
    "live",
    access_token: refreshed["access_token"]
  )

{:ok, health} =
  LiveWorkflow.stream_health(stream["id"], access_token: refreshed["access_token"])
```

Direct unsafe jumps such as `ready -> live` return
`{:error, {:unsafe_transition, "ready", "live"}}`.

## Live Chat

Read, poll, and write chat messages using the live chat id from the broadcast
snippet:

```elixir
live_chat_id = get_in(broadcast, ["snippet", "liveChatId"])

{:ok, messages} =
  LiveWorkflow.poll_chat_messages(live_chat_id, %{
    access_token: refreshed["access_token"],
    max_pages: 3
  })

{:ok, sent} =
  LiveWorkflow.send_chat_message(live_chat_id, "We are live.", %{
    access_token: refreshed["access_token"]
  })
```

All examples are credential-gated. Tests use `Req.Test` mocks and do not require
real YouTube credentials.
