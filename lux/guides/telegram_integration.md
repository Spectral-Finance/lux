# Telegram Core API Integration

Lux provides a comprehensive integration with the Telegram Bot API, including inbound update processing (Webhooks & Polling), outgoing requests with automated rate-limit handling, and robust failure recovery.

## Getting Started

Set your `TELEGRAM_BOT_TOKEN` in your environment or configuration.

```elixir
config :lux, :api_keys,
  telegram_bot: System.get_env("TELEGRAM_BOT_TOKEN")
```

## Outbound Requests & Rate Limiting

The `Lux.Integrations.Telegram.Client` uses a global rate-limiting queue (`Lux.Integrations.Telegram.Queue`).

When you make a request, the queue automatically parses `429 Too Many Requests` responses and respects the `retry_after` parameter, pausing further requests to that endpoint until the rate limit expires.

```elixir
# The Client will automatically handle 429s for you
Lux.Integrations.Telegram.Client.request(:post, "/sendMessage", %{
  json: %{
    chat_id: 123456789,
    text: "Hello, World!"
  }
})
```

## Inbound Updates

You can receive updates from Telegram via Long-Polling (recommended for development) or Webhooks (recommended for production).

### Polling

Start the `Lux.Integrations.Telegram.Poller` in your supervision tree, providing a handler module that exports `handle_update/1`:

```elixir
defmodule MyTelegramHandler do
  def handle_update(%{"message" => message}) do
    IO.puts("Received message: #{message["text"]}")
  end
  def handle_update(_), do: :ok
end

# In your application.ex
children = [
  {Lux.Integrations.Telegram.Poller, handler: MyTelegramHandler}
]
```

### Webhooks

For production, configure the Webhook Plug in your router or endpoint. Telegram sends a secret token in the `X-Telegram-Bot-Api-Secret-Token` header, which the Plug automatically verifies.

```elixir
plug Lux.Integrations.Telegram.Webhook, 
  secret_token: System.get_env("TELEGRAM_WEBHOOK_SECRET"),
  handler: MyTelegramHandler
```

## Custom Keyboards

The messaging prisms, such as `SendMessage`, fully support `reply_markup` for inline keyboards and custom reply keyboards.

```elixir
Lux.Prisms.Telegram.Messages.SendMessage.handler(%{
  chat_id: 12345,
  text: "Choose an option:",
  reply_markup: %{
    inline_keyboard: [
      [
        %{text: "Option 1", callback_data: "opt1"},
        %{text: "Option 2", callback_data: "opt2"}
      ]
    ]
  }
}, %{})
```

## Security 

Lux ensures that your Telegram Bot Token is never accidentally leaked in transport logs. The `Req` HTTP client interceptor explicitly strips the token from the URL and replaces it with `***` on any transport failure.
