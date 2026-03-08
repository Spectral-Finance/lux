# Telegram Core API Integration

Complete Telegram Bot API integration for Lux agents with secure authentication, rate limiting, webhook support, and comprehensive message handling.

## Quick Start

```elixir
alias Lux.Prisms.Telegram.SendMessage

# Send a message
{:ok, msg} = SendMessage.handler(%{
  chat_id: 123456789,
  text: "Hello from Lux! 🤖",
  token: "YOUR_BOT_TOKEN"
}, [])
```

## Bot Authentication

```elixir
alias Lux.Lenses.Telegram.GetMe

# Verify bot token
{:ok, bot} = GetMe.focus(%{token: "YOUR_BOT_TOKEN"})
IO.puts("Bot: @#{bot["username"]}")
```

## Messaging

### Send Messages
```elixir
# Plain text
SendMessage.handler(%{chat_id: id, text: "Hello!", token: token}, [])

# Markdown
SendMessage.handler(%{
  chat_id: id,
  text: "*Bold* and _italic_",
  parse_mode: "Markdown",
  token: token
}, [])

# With inline keyboard
SendMessage.handler(%{
  chat_id: id,
  text: "Choose an option:",
  reply_markup: %{
    inline_keyboard: [
      [%{text: "✅ Yes", callback_data: "yes"}, %{text: "❌ No", callback_data: "no"}]
    ]
  },
  token: token
}, [])
```

### Edit & Delete
```elixir
alias Lux.Prisms.Telegram.{EditMessage, DeleteMessage}

# Edit
EditMessage.handler(%{chat_id: id, message_id: 123, text: "Updated!", token: token}, [])

# Delete
DeleteMessage.handler(%{chat_id: id, message_id: 123, token: token}, [])
```

### Send Media
```elixir
alias Lux.Prisms.Telegram.SendMedia

# Photo
SendMedia.handler(%{chat_id: id, media_type: "photo", media: "https://example.com/photo.jpg", caption: "Nice!", token: token}, [])

# Document, voice, video, audio
SendMedia.handler(%{chat_id: id, media_type: "document", media: "BQACAgI...", token: token}, [])
```

## Webhooks

```elixir
alias Lux.Prisms.Telegram.ManageWebhook

# Set webhook
ManageWebhook.handler(%{action: "set", url: "https://your-domain.com/webhook", token: token}, [])

# Get info
ManageWebhook.handler(%{action: "info", token: token}, [])

# Delete
ManageWebhook.handler(%{action: "delete", token: token}, [])
```

### Processing Updates
```elixir
alias Lux.Integrations.Telegram.WebhookHandler

# Parse incoming update
{:ok, update} = WebhookHandler.parse_update(raw_payload)

case update.type do
  :message ->
    case WebhookHandler.extract_command(update) do
      {"start", _args} -> handle_start(update)
      {"help", _args} -> handle_help(update)
      :not_command -> handle_message(update)
    end

  :callback_query ->
    handle_callback(update.content.data)

  :inline_query ->
    handle_inline(update.content.query)
end
```

## Callback Queries

```elixir
alias Lux.Prisms.Telegram.AnswerCallbackQuery

# Answer callback
AnswerCallbackQuery.handler(%{callback_query_id: "cb123", text: "Done!", token: token}, [])

# Alert popup
AnswerCallbackQuery.handler(%{callback_query_id: "cb123", text: "Error!", show_alert: true, token: token}, [])
```

## Rate Limiting

```elixir
alias Lux.Integrations.Telegram.RateLimiter

{:ok, pid} = RateLimiter.start_link()

# Check before sending
case RateLimiter.acquire(pid, chat_id) do
  :ok -> SendMessage.handler(params, [])
  {:wait, ms} -> Process.sleep(ms); SendMessage.handler(params, [])
end

# Limits enforced:
# - 30 msg/sec globally
# - 1 msg/sec per chat
# - 20 msg/min per group
```

## Polling Updates

```elixir
alias Lux.Lenses.Telegram.GetUpdates

{:ok, updates} = GetUpdates.focus(%{
  token: token,
  offset: 0,
  limit: 100,
  timeout: 30
})
```

## File Downloads

```elixir
alias Lux.Lenses.Telegram.GetFile

{:ok, file} = GetFile.focus(%{file_id: "AgACAgIAA...", token: token})
download_url = file["download_url"]
```
