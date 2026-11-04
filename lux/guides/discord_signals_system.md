# Discord Signals System in Lux

The Discord Signals System standardizes all Discord events (messages, interactions, presence updates, and voice state transitions) into strongly typed, schema-validated Lux Signals. This enables AI agents to consume, validate, reason about, and emit Discord communications through uniform pipeline primitives.

---

## 1. System Architecture

```
+-------------------------------------------------------------------------+
|                          Discord Gateway / REST                         |
+------------------------------------+------------------------------------+
                                     | Raw Event JSON
                                     v
+-------------------------------------------------------------------------+
|                  DiscordSignalPipelineBeam (Pipeline)                   |
|                                                                         |
|  1. Parse Event  -->  2. Validate Signal  -->  3. Route  -->  4. Emit   |
+------------------------------------+------------------------------------+
                                     |
         +---------------------------+---------------------------+
         |                           |                           |
         v                           v                           v
+------------------+       +-------------------+       +------------------+
|  MessageSignal   |       | InteractionSignal |       |  PresenceSignal  |
| (Content/Embeds) |       | (Slash/Buttons)   |       | (Status/Games)   |
+------------------+       +-------------------+       +------------------+
         |                           |                           |
         +---------------------------+---------------------------+
                                     |
                                     v
                        +-------------------------+
                        |       VoiceSignal       |
                        | (Speaking/Mute/Deaf)    |
                        +-------------------------+
```

---

## 2. Core Signal Types

### `Lux.Signals.Discord.MessageSignal`
Encapsulates message content, author identity, attachments, rich embeds, and UI components:

```elixir
{:ok, signal} = Lux.Signals.Discord.MessageSignal.new(%{
  content: "Execute trade order 0.5 ETH",
  channel_id: "1234567890",
  author: %{id: "999", username: "trader_alice"}
})
```

### `Lux.Signals.Discord.InteractionSignal`
Encapsulates slash command invocations, button clicks, select menus, and modal submissions:

```elixir
{:ok, signal} = Lux.Signals.Discord.InteractionSignal.new(%{
  interaction_id: "int_12345",
  type: "slash_command",
  name: "portfolio_summary",
  user_id: "999"
})
```

### `Lux.Signals.Discord.PresenceSignal`
Encapsulates user online status, game streaming, and custom status messages:

```elixir
{:ok, signal} = Lux.Signals.Discord.PresenceSignal.new(%{
  user_id: "999",
  status: "online",
  activities: [%{name: "Lux Autonomous Agent", type: 0}]
})
```

### `Lux.Signals.Discord.VoiceSignal`
Encapsulates voice channel connections, speaking indicators, and mute/deaf state:

```elixir
{:ok, signal} = Lux.Signals.Discord.VoiceSignal.new(%{
  user_id: "999",
  guild_id: "guild_888",
  channel_id: "voice_777",
  action: "speaking",
  speaking: true
})
```

---

## 3. Bidirectional Conversion (`Lux.Signals.Discord.Converter`)

Translates raw Discord JSON into Lux Signals and converts Signals back to outgoing Discord payloads:

```elixir
# Raw Gateway payload -> Lux Signal
{:ok, signal} = Lux.Signals.Discord.Converter.to_signal("MESSAGE_CREATE", raw_json)

# Lux Signal -> Discord API format
{:ok, discord_payload} = Lux.Signals.Discord.Converter.to_discord_payload(signal)
```

---

## 4. Signal Processing Pipeline (`Lux.Signals.Discord.Pipeline`)

Coordinates ingestion, schema validation, and dispatch to agent subscribers:

```elixir
# Process incoming raw event
{:ok, signal} = Lux.Signals.Discord.Pipeline.process_event("MESSAGE_CREATE", event_data)

# Dispatch to agent handler
Lux.Signals.Discord.Pipeline.dispatch(signal, Lux.Agents.DiscordAgent)
```

---

## 5. Dedicated Prisms

- **`Lux.Prisms.Discord.Signals.ParseSignalPrism`**: Ingests raw event JSON and produces typed signals.
- **`Lux.Prisms.Discord.Signals.ValidateSignalPrism`**: Enforces schema constraints and catches formatting errors.
- **`Lux.Prisms.Discord.Signals.RouteSignalPrism`**: Directs signals to subscribed agents.
- **`Lux.Prisms.Discord.Signals.EmitSignalPrism`**: Packages signals into outbound Discord API payloads.

---

## 6. Pipeline Orchestration Beam

Run the full signal cycle using `Lux.Beams.Discord.Signals.DiscordSignalPipelineBeam`:

```elixir
{:ok, result} = Lux.Beams.Discord.Signals.DiscordSignalPipelineBeam.run(%{
  event_type: "MESSAGE_CREATE",
  payload: %{
    "content" => "Requesting portfolio audit",
    "channel_id" => "123456789012345678",
    "author" => %{"id" => "42", "username" => "fund_manager"}
  }
})
```
