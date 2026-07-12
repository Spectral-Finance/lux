# Discord Community Management

The Discord community management prisms allow your Lux agents to interact with Discord servers seamlessly. This guide covers how to use the prisms for managing messages, channels, moderation actions, and scheduled events.

**Note:** This implementation is Prism-only (representing a reduced scope for Issue #57) to provide the foundational operations before adding full Lens, Agent, and tool support.

## Core Prisms

1. **MessageManagementPrism**: Create, edit, delete, bulk delete, and fetch message history.
2. **ChannelManagementPrism**: Create, update, delete, and fetch channel data.
3. **ModerationPrism**: Apply timeouts, bans, unbans, and kick members.
4. **EventHandlingPrism**: Create, update, delete, and list scheduled events.

## Rate Limiting and Error Handling

All Discord prisms include a built-in retry mechanism for HTTP 429 (Too Many Requests) errors.
By default, the prisms will automatically wait and retry the request up to 3 times before returning an error.

If a required parameter is missing, the prism will return `{:error, "param_name is required"}` instead of raising an exception. This allows your agent to gracefully handle bad inputs.

### String-Key Compatibility

All Discord prisms are compatible with both atom keys (standard Elixir) and string keys (common when handling raw JSON payloads from LLMs or external systems). You do not need to manually parse or symbolize the input schema.

## Examples

### 1. Sending a Message
```elixir
Lux.Prisms.Discord.MessageManagementPrism.handler(%{
  "action" => "create",
  "channel_id" => "123456789",
  "content" => "Hello from Lux!"
}, %{name: "DiscordAgent"})
```

### 2. Banning a User
```elixir
Lux.Prisms.Discord.ModerationPrism.handler(%{
  "action" => "ban",
  "guild_id" => "987654321",
  "user_id" => "1122334455",
  "delete_message_seconds" => 86400,
  "reason" => "Spamming the general channel"
}, %{name: "DiscordAgent"})
```

### 3. Creating a Scheduled Event
```elixir
Lux.Prisms.Discord.EventHandlingPrism.handler(%{
  "action" => "create",
  "guild_id" => "987654321",
  "name" => "Weekly Community Call",
  "privacy_level" => 2,
  "scheduled_start_time" => "2026-07-06T18:00:00Z",
  "scheduled_end_time" => "2026-07-06T19:00:00Z",
  "description" => "Join us for the weekly updates!"
}, %{name: "DiscordAgent"})
```
