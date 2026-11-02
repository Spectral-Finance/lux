# Telegram Core API Integration Guide

This guide details the architecture, design principles, and operational workflows for the Telegram Bot API Core Integration in Lux.

---

## 1. Architecture Overview

Lux provides a native, end-to-end integration with the Telegram Bot API. Designed for high-reliability autonomous agents, this module supports secure token custody, rate-limited queuing, structured lens interfaces, webhook update dispatching, and agent Prism execution.

```mermaid
flowchart TD
    Agent[Autonomous Agent / Prism] --> Facade[Lux.Integrations.Telegram]
    Facade --> Client[Telegram.Client\n(Req HTTP, Error translation, Header parsing)]
    Facade --> TokenManager[Telegram.TokenManager\n(AES-256-GCM, Multi-Bot Registry, Masking)]
    Facade --> RateLimiter[Telegram.RateLimiter\n(Global 30/s, Chat 1/s, 429 retry_after)]
    Facade --> RateLimitQueue[Telegram.RateLimitQueue\n(Priority Queue: High, Normal, Low)]
    Facade --> Updates[Telegram.UpdatesHandler\n(Webhook secret validation & Normalization)]
    
    Agent --> Lenses[Lux.Lenses.Telegram\n(GetMe, SendMessage, EditMessage, Media, Webhooks, Updates)]
```

---

## 2. Core Modules & Capabilities

### 2.1 Secure Token Management (`Lux.Integrations.Telegram.TokenManager`)
- **Format Validation**: Strict regex verification (`^[0-9]{8,12}:[a-zA-Z0-9_-]{35}$`) before token storage.
- **AES-256-GCM Encryption**: Encrypts sensitive bot tokens at rest with PBKDF2 salt derivation (100,000 iterations).
- **Multi-Bot Registry**: Manages multiple bot tokens in a single agent environment.
- **Token Masking**: Redacts tokens in logs (e.g. `123456789:ABCD...XYZ`).

### 2.2 Rate Limiting & Priority Queueing (`Lux.Integrations.Telegram.RateLimiter` & `RateLimitQueue`)
Adheres strictly to Telegram's official API limits:
- **Global Limit**: Maximum 30 messages/second across all chats.
- **Private Chat Limit**: Maximum 1 message/second per private chat.
- **Group/Channel Limit**: Maximum 20 messages/minute per group.
- **Dynamic 429 Handling**: Automatically parses `parameters.retry_after` from Telegram error payloads and enforces penalties.
- **Priority Bands**: Dispatches messages based on priority (`:high` for urgent security/alerts, `:normal` for bot conversations, `:low` for broadcasts).

### 2.3 Webhooks & Update Normalization (`Lux.Integrations.Telegram.UpdatesHandler`)
- **Secret Token Verification**: Authenticates `X-Telegram-Bot-Api-Secret-Token` via constant-time SHA-256 comparison.
- **Normalized Updates**: Parses incoming `Update` events into standardized maps (`:message`, `:callback_query`, `:inline_query`, `:channel_post`).
- **Long Polling**: Native support for `/getUpdates` with offset management and timeouts.

### 2.4 Telegram Lens System (`Lux.Lenses.Telegram.*`)
Dedicated lenses for compositional pipeline execution:
- `Lux.Lenses.Telegram.Bot.GetMe`: Validates bot credentials.
- `Lux.Lenses.Telegram.Messages.SendMessage`: Dispatches text with parse modes (MarkdownV2, HTML).
- `Lux.Lenses.Telegram.Messages.EditMessageText`: Modifies existing messages.
- `Lux.Lenses.Telegram.Messages.DeleteMessage`: Removes messages.
- `Lux.Lenses.Telegram.Messages.ForwardMessage`: Forwards messages across chats.
- `Lux.Lenses.Telegram.Media.SendPhoto`: Delivers images via URL or file_id.
- `Lux.Lenses.Telegram.Media.SendDocument`: Sends arbitrary documents and files.
- `Lux.Lenses.Telegram.Webhooks.SetWebhook`: Configures webhook callback endpoints.
- `Lux.Lenses.Telegram.Webhooks.GetWebhookInfo`: Inspects current webhook diagnostics.
- `Lux.Lenses.Telegram.Updates.GetUpdates`: Polling endpoint for updates.

---

## 3. Autonomous Agent Prism Usage

Agents invoke the infrastructure seamlessly using `Lux.Prisms.TelegramCorePrism`:

```elixir
# 1. Send an urgent alert to Telegram chat
{:ok, %{result: sent}} =
  Lux.Prisms.TelegramCorePrism.run(%{
    action: "send_message",
    payload: %{
      chat_id: 123456789,
      text: "🚨 <b>System Notice</b>: Agent has rebalanced treasury.",
      parse_mode: "HTML"
    }
  })

# 2. Enqueue message in rate-limited priority queue
{:ok, %{result: queued}} =
  Lux.Prisms.TelegramCorePrism.run(%{
    action: "enqueue_message",
    payload: %{
      chat_id: 123456789,
      message: %{"text" => "Bulk agent update"},
      priority: :high
    }
  })

# 3. Configure webhook endpoint with security secret
{:ok, %{result: webhook}} =
  Lux.Prisms.TelegramCorePrism.run(%{
    action: "set_webhook",
    payload: %{
      url: "https://agent.company.xyz/api/telegram/webhook",
      secret_token: "lux_super_secure_secret_token"
    }
  })
```

---

## 4. Performance Benchmarks

Run the benchmark suite using:
```bash
mix run test/benchmarks/telegram_rate_limiter_benchmark.exs
```
Sample benchmark results:
- **RateLimiter**: ~350,000 checks/sec
- **PriorityQueue**: ~180,000 enqueues/dequeues per sec
- **AES-256-GCM Crypto**: < 0.15 ms per token cycle
