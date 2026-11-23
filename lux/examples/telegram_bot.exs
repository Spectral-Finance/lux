# Telegram Integration Example

This example demonstrates how to use the Lux Telegram integration to build a simple bot.

## Setup

1. Create a bot with [@BotFather](https://t.me/BotFather) on Telegram
2. Copy the bot token
3. Set the environment variable:

```bash
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
```

## Basic Bot

```elixir
# Run with: elixir examples/telegram_bot.exs

alias Lux.Integrations.Telegram.Prisms.GetMe
alias Lux.Integrations.Telegram.Prisms.GetUpdates
alias Lux.Integrations.Telegram.Prisms.SendMessage

# 1. Verify the bot token
{:ok, bot_info} = GetMe.handler(%{}, %{})
IO.puts("Bot connected: @#{bot_info.result["username"]}")

# 2. Get updates (long polling)
{:ok, updates} = GetUpdates.handler(%{timeout: 30}, %{})

for update <- updates.result do
  if message = update["message"] do
    chat_id = message["chat"]["id"]
    text = message["text"]

    IO.puts("Received: #{text}")

    # Echo the message back
    SendMessage.handler(%{
      chat_id: chat_id,
      text: "You said: #{text}"
    }, %{})
  end
end
```

## Webhook Setup

```elixir
alias Lux.Integrations.Telegram.Prisms.SetWebhook
alias Lux.Integrations.Telegram.Prisms.GetWebhookInfo

# Set webhook to your HTTPS endpoint
{:ok, _} = SetWebhook.handler(%{
  url: "https://your-domain.com/telegram/webhook",
  secret_token: "your-secret-token"
}, %{})

# Check webhook status
{:ok, info} = GetWebhookInfo.handler(%{}, %{})
IO.inspect(info.result)
```

## Rate Limiting

The integration automatically handles rate limiting:

```elixir
alias Lux.Integrations.Telegram.RateLimiter

# Check current rate limit state
state = RateLimiter.get_state()
IO.inspect(state)
# => %{tokens: 25, rate_limit: 30, burst_limit: 30, queue_size: 0}

# Enqueue messages for later processing
for i <- 1..100 do
  RateLimiter.enqueue({:send_message, %{chat_id: 123, text: "Message #{i}"}})
end
```

## Error Handling

```elixir
alias Lux.Integrations.Telegram.ErrorHandler

# Execute with automatic retry
result = ErrorHandler.with_retry(fn ->
  Client.request(:get, "/getMe", %{token: token})
end)

case result do
  {:ok, response} ->
    IO.puts("Success: #{response["result"]["username"]}")

  {:error, error} ->
    IO.puts("Failed: #{error.description}")
end
```

## Secure Token Management

```elixir
alias Lux.Integrations.Telegram.TokenManager

# Resolve token from config/env
{:ok, token} = TokenManager.resolve_token([])

# Validate token format
case TokenManager.validate_token(token) do
  {:ok, _} -> IO.puts("Token is valid")
  {:error, reason} -> IO.puts("Invalid token: #{reason}")
end

# Safe logging (token is masked)
Logger.info("Using token: #{TokenManager.mask_token(token)}")
# => "Using token: 1234...W2v1"