# Discord Core Prisms

Lux includes Discord prisms and lenses for building moderation, community operations, and event workflows.

## Message Management

- `Lux.Prisms.Discord.Messages.SendMessage`
- `Lux.Prisms.Discord.Messages.EditMessage`
- `Lux.Prisms.Discord.Messages.DeleteMessage`
- `Lux.Prisms.Discord.Messages.PinMessage`
- `Lux.Prisms.Discord.Messages.ReactToMessage`
- `Lux.Lenses.Discord.Messages.ListMessages`
- `Lux.Lenses.Discord.Messages.ReadMessage`

## Channel Management

- `Lux.Prisms.Discord.Channels.CreateChannel`
- `Lux.Prisms.Discord.Channels.DeleteChannel`
- `Lux.Lenses.Discord.Channels.ListChannels`
- `Lux.Lenses.Discord.Channels.ReadChannel`

## Moderation

- `Lux.Prisms.Discord.Moderation.TimeoutMember`
- `Lux.Prisms.Discord.Moderation.RemoveTimeout`
- `Lux.Prisms.Discord.Moderation.BanMember`
- `Lux.Prisms.Discord.Moderation.UnbanMember`

Moderation prisms accept an optional `reason` field. When present, Lux forwards it as the Discord `X-Audit-Log-Reason` header so guild audit logs explain agent actions.

## Events

- `Lux.Prisms.Discord.Events.CreateScheduledEvent`
- `Lux.Prisms.Discord.Events.CancelScheduledEvent`

`CreateScheduledEvent` supports Discord voice events (`entity_type: 2`) and external events (`entity_type: 3`). Voice events require `channel_id`; external events require `location`.

## Testing

Focused tests use `Req.Test` and the shared `DiscordClientMock`, so they verify HTTP method, path, JSON body, and audit-log headers without calling the live Discord API.
