# Discord Integration

Lux includes Discord lenses for read operations and Discord prisms for actions
that agents can execute.

## Configuration

Set `DISCORD_API_KEY` to a bot token with the permissions required by the
target guild and channels.

## Message Operations

- `Lux.Prisms.Discord.Messages.SendMessage`
- `Lux.Prisms.Discord.Messages.EditMessage`
- `Lux.Prisms.Discord.Messages.DeleteMessage`
- `Lux.Prisms.Discord.Messages.BulkDeleteMessages`
- `Lux.Prisms.Discord.Messages.ReactToMessage`
- `Lux.Prisms.Discord.Messages.PinMessage`

Bulk deletion accepts 2 to 100 message IDs:

```elixir
Lux.Prisms.Discord.Messages.BulkDeleteMessages.run(%{
  channel_id: "223456789012345678",
  message_ids: ["323456789012345678", "423456789012345678"],
  reason: "cleanup spam"
})
```

## Channel Operations

- `Lux.Prisms.Discord.Channels.CreateChannel`
- `Lux.Prisms.Discord.Channels.UpdateChannel`
- `Lux.Prisms.Discord.Channels.DeleteChannel`
- `Lux.Prisms.Discord.Channels.SetChannelPermissions`

Permission overwrites use Discord's bitset strings:

```elixir
Lux.Prisms.Discord.Channels.SetChannelPermissions.run(%{
  channel_id: "223456789012345678",
  overwrite_id: "623456789012345678",
  overwrite_type: 0,
  allow: "1024",
  deny: "2048",
  reason: "grant view channel"
})
```

## Moderation Operations

- `Lux.Prisms.Discord.Moderation.TimeoutMember`
- `Lux.Prisms.Discord.Moderation.BanMember`
- `Lux.Prisms.Discord.Moderation.UnbanMember`

Timeouts use Discord's `communication_disabled_until` field. Pass `nil` or an
empty string to clear a timeout.

```elixir
Lux.Prisms.Discord.Moderation.TimeoutMember.run(%{
  guild_id: "123456789012345678",
  user_id: "523456789012345678",
  communication_disabled_until: "2026-05-13T16:30:00Z",
  reason: "cooldown"
})
```

## Scheduled Events

- `Lux.Prisms.Discord.Events.CreateScheduledEvent`
- `Lux.Prisms.Discord.Events.DeleteScheduledEvent`

External scheduled events require a start time, end time, and location:

```elixir
Lux.Prisms.Discord.Events.CreateScheduledEvent.run(%{
  guild_id: "123456789012345678",
  name: "Launch Review",
  scheduled_start_time: "2026-05-13T17:00:00Z",
  scheduled_end_time: "2026-05-13T18:00:00Z",
  location: "Discord Stage",
  description: "Release checklist"
})
```

## Rate Limits

New Discord core prisms call `Lux.Integrations.Discord.Client.request_with_retry/3`.
It retries bounded 429 and 5xx responses with exponential backoff. The base
request function remains unchanged for existing integrations.
