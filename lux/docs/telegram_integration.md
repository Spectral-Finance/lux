# Lux Telegram Integration

Complete production-grade Telegram Bot API integration for the Lux workflow framework.

## Overview

This integration provides:

- **5 Prism Behaviors** for Telegram Bot API operations (GetMe, GetUpdates, SetWebhook, DeleteWebhook, GetWebhookInfo)
- **Secure token management** with validation and masking
- **Rate limiting** with token-bucket queueing (30 req/sec default)
- **Retry/error handling** with exponential backoff and Telegram-specific error classification
- **Webhook support** for receiving updates from Telegram

## Quick Start

### 1. Configure your bot token

```elixir
# config/runtime.exs
config :lux,
  api_keys: [
    telegram_bot: System.get_env("TELEGRAM_BOT_TOKEN")
  ]
```

### 2. Use the prisms in a workflow

```elixir
alias Lux.Integrations.Telegram.Prisms.GetMe

# Get bot information
{:ok, bot_info} = GetMe.handler(%{}, %{})
IO.inspect(bot_info, label: "Bot Info")
# => %{ok: true, result: %{"username" => "my_bot", ...}}
```

### 3. Send messages

```elixir
alias Lux.Integrations.Telegram.Prisms.SendMessage

{:ok, response} = SendMessage.handler(%{
  chat_id: 123456789,
  text: "Hello from Lux!"
}, %{})
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Telegram Bot API                      │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│              Lux.Integrations.Telegram.Client            │
│  (HTTP client with Req, token resolution, error parsing) │
└─────────────────────────┬───────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼───────┐ ┌──────▼──────� ┌───────▼────────┐
│ TokenManager  │ │RateLimiter  │ │ ErrorHandler   │
│ (secure token │ │ (token-     │ │ (retry/backoff │
│  resolution)  │ │  bucket)    │ │  + classify)   │
└───────────────┘ └─────────────┘ └────────────────┘
```

## Modules

### Lux.Integrations.Telegram.Client

Low-level HTTP client for the Telegram Bot API.

```elixir
# Make a GET request
{:ok, response} = Client.request(:get, "/getMe", %{token: token})

# Make a POST request with JSON body
{:ok, response} = Client.request(:post, "/sendMessage", %{
  token: token,
  json: %{chat_id: 123, text: "Hello"}
})
```

### Lux.Integrations.Telegram.TokenManager

Secure token resolution and validation.

```elixir
# Resolve token from options, config, or env
{:ok, token} = TokenManager.resolve_token(token: "123456:ABC-DEF")

# Validate token format
{:ok, token} = TokenManager.validate_token("123456:ABC-DEF")

# Mask token for safe logging
masked = TokenManager.mask_token(token)
# => "1234...W2v1"
```

### Lux.Integrations.Telegram.RateLimiter

Token-bucket rate limiter with queueing.

```elixir
# Check and wait for rate limit
:ok = RateLimiter.check_and_wait(:send_message)

# Enqueue a request
:ok = RateLimiter.enqueue({:send_message, %{chat_id: 123}})

# Get current state
state = RateLimiter.get_state()
# => %{tokens: 25, rate_limit: 30, burst_limit: 30, queue_size: 0}
```

### Lux.Integrations.Telegram.ErrorHandler

Retry logic with exponential backoff and error classification.

```elixir
# Execute with retry
{:ok, result} = ErrorHandler.with_retry(fn ->
  Client.request(:get, "/getMe", %{token: token})
end)

# Classify errors
:retryable = ErrorHandler.classify_error(%{code: 429, description: "Too Many Requests"})
:fatal = ErrorHandler.classify_error(%{code: 401, description: "Unauthorized"})
```

## Prisms

### GetMe

Get information about the bot.

**Input:** `%{}` (token from config)

**Output:** `{:ok, %{ok: true, result: %{...}}}`

### GetUpdates

Receive incoming updates (long polling).

**Input:**
- `:offset` (optional) — update identifier to start from
- `:limit` (optional) — number of updates to return (1-100)
- `:timeout` (optional) — long polling timeout in seconds

**Output:** `{:ok, %{ok: true, result: [...]}}`

### SetWebhook

Set the webhook URL for receiving updates.

**Input:**
- `:url` (required) — HTTPS URL for webhook
- `:secret_token` (optional) — secret token for verification

**Output:** `{:ok, %{ok: true, result: true}}`

### DeleteWebhook

Remove the webhook.

**Input:** `%{}`

**Output:** `{:ok, %{ok: true, result: true}}`

### GetWebhookInfo

Get current webhook status.

**Input:** `%{}`

**Output:** `{:ok, %{ok: true, result: %{...}}}`

## Rate Limits

Telegram Bot API rate limits:

| Operation | Limit |
|-----------|-------|
| Messages to different users | ~30/sec |
| Messages to same chat | 1/sec (bursts allowed) |
| Messages to same group | 20/min |

The `RateLimiter` automatically handles these limits with a token-bucket algorithm.

## Error Handling

Errors are classified as:

- **`:retryable`** — 429 (rate limit), 5xx (server error), network errors
- **`:fatal`** — 400 (bad request), 401 (unauthorized), 403 (forbidden), 404 (not found)

Retryable errors are retried with exponential backoff (up to 3 retries by default).

## Testing

```bash
# Run unit tests
mix test test/unit/lux/integrations/telegram/

# Run with coverage
mix coveralls
```

## Security

- Tokens are never logged (masked in output)
- Token comparison uses constant-time comparison
- Tokens are validated for format before use
- Webhook secret tokens are supported for verification