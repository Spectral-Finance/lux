# Lux Telegram Integration

A comprehensive Telegram Bot API integration for the Lux framework, providing both core API functionality and advanced interactive features.

## Overview

The Telegram integration module provides a complete solution for building Telegram bots using Lux's lens system. It includes core API functionality, interactive features, rate limiting, error handling, and both polling and webhook support.

## Features

### Core Functionality
- Bot authentication and management
- Message handling (send, receive, edit, delete)
- Media file handling (photos, documents, voice messages)
- Webhook integration and updates handling
- Rate limit management
- Error handling with retry mechanisms

### Interactive Features
- Polls and quizzes
- Games with score tracking
- Live location sharing
- Sticker handling
- Inline query processing
- Interactive keyboards

### Group Management Features
- Member management (add, remove, restrict, promote)
- Permission management for groups and channels
- Content moderation (delete messages, clean up history)
- Spam protection (restrict new users, set slow mode)
- Group settings management (title, description, photo)
- Channel post management
- Admin action logging

## Installation

The Telegram integration is part of the Lux framework. Ensure you have the following in your `mix.exs`:

```elixir
def deps do
  [
    {:lux, "~> 0.1.0"}
  ]
end
```

## Configuration

Add your Telegram bot token to your configuration:

```elixir
# config/config.exs
config :lux, :api_keys,
  telegram_bot: "YOUR_BOT_TOKEN"
```

## Usage

### Basic Example

```elixir
alias Lux.Lenses.TelegramBotLens

# Send a message
TelegramBotLens.send_message(chat_id, "Hello from Lux!")

# Send a photo
TelegramBotLens.send_photo(chat_id, "https://example.com/photo.jpg", %{
  caption: "Check out this photo!"
})

# Create a poll
TelegramBotLens.send_poll(chat_id, "What's your favorite color?", [
  "Blue", "Red", "Green"
])
```

### Interactive Features

```elixir
# Create a quiz
TelegramBotLens.send_quiz(chat_id, "What's the capital of France?", [
  "London", "Berlin", "Paris", "Madrid"
], 2)

# Send live location
TelegramBotLens.send_live_location(chat_id, latitude, longitude, 60)

# Handle inline queries
TelegramBotLens.set_inline_handler(fn query ->
  [
    TelegramBotLens.create_article_result(
      "1",
      "Search Result",
      TelegramBotLens.create_text_content("You searched for: #{query["query"]}")
    )
  ]
end)
```

### Group Management Features

```elixir
alias Lux.Lenses.TelegramGroupManagementFeatures

# Ban a user from a group
TelegramGroupManagementFeatures.ban_chat_member(chat_id, user_id)

# Restrict a user in a group
TelegramGroupManagementFeatures.restrict_chat_member(
  chat_id,
  user_id,
  %{
    can_send_messages: false,
    until_date: :os.system_time(:second) + 3600 # 1 hour
  }
)

# Promote a user to admin
TelegramGroupManagementFeatures.promote_chat_member(
  chat_id,
  user_id,
  %{
    can_delete_messages: true,
    can_restrict_members: true
  }
)

# Set chat permissions for all members
TelegramGroupManagementFeatures.set_chat_permissions(
  chat_id,
  %{
    can_send_messages: true,
    can_send_media_messages: true,
    can_send_polls: false
  }
)

# Create an invite link
TelegramGroupManagementFeatures.create_chat_invite_link(
  chat_id,
  %{
    name: "Special Invite",
    expire_date: :os.system_time(:second) + 86400, # 24 hours
    member_limit: 10
  }
)

# Set slow mode
TelegramGroupManagementFeatures.set_chat_slow_mode_delay(chat_id, 30) # 30 seconds
```

## Example Bots

The module includes several example bots demonstrating different features:

### Echo Bot (Polling)
```bash
mix telegram.echo_bot YOUR_BOT_TOKEN
```

### Webhook Echo Bot
```bash
mix telegram.webhook_echo_bot YOUR_BOT_TOKEN [MAX_RUNTIME] [PORT]
```

### Game Bot
```bash
mix telegram.game_bot YOUR_BOT_TOKEN
```

### Group Management Example
```bash
mix telegram.group_management_example CHAT_ID YOUR_BOT_TOKEN [SECTION] [USER_ID]
```

### Complete Example
```bash
mix telegram.complete_example CHAT_ID BOT_TOKEN [WEBHOOK_URL]
```

## Rate Limiting

The module implements Telegram's rate limits:
- 30 messages per second globally
- 1 message per second per chat
- 20 messages per minute per group

Rate limiting is handled automatically by the `RateLimiter` module.

## Error Handling

The `ErrorHandler` module provides:
- Automatic retries for transient errors
- Exponential backoff
- Error categorization
- Timeout handling

## Webhook Support

For webhook-based bots:
1. Enable webhooks via @BotFather
2. Use `ngrok` or similar for local development
3. Set up the webhook:
```elixir
TelegramBotLens.set_webhook("https://your-domain.com/webhook")
```

## Testing

Run the test suite:
```bash
mix test test/unit/lux/lenses/telegram
```

The test suite includes:
- Unit tests for core functionality
- Integration tests for API interactions
- Rate limit compliance tests
- Error handling verification

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This module is part of the Lux framework and is available under the same license.

## Support

For issues and feature requests, please use the GitHub issue tracker.

## Documentation

For detailed documentation:
- Run `mix docs` to generate documentation
- See the [Lux Documentation](https://hexdocs.pm/lux)
- Check the [Telegram Bot API Documentation](https://core.telegram.org/bots/api)