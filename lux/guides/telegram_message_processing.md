# Telegram Message Processing

Lux includes pure Telegram update-processing helpers plus prisms for agents that need to route Telegram Bot API updates without making a network call.

## Helpers

`Lux.Integrations.Telegram.MessageProcessing.analyze_update/2` accepts a raw Telegram update map and returns:

- update/message type classification
- chat and user IDs
- text or caption
- slash command parsing with quoted arguments and bot mentions
- `/start` deep-link payload extraction
- thread and reply context
- callback query context
- Telegram MarkdownV2 and HTML escaping helpers

```elixir
analysis = Lux.Integrations.Telegram.MessageProcessing.analyze_update(update, bot_username: "LuxBot")

case analysis.command do
  %{command: "trade", args: [side, symbol | rest], addressed?: true} ->
    # route to a trading prism/beam
  _ ->
    :ignore
end
```

## Prisms

- `Lux.Prisms.Telegram.Processing.AnalyzeUpdate`
- `Lux.Prisms.Telegram.Processing.ParseCommand`
- `Lux.Prisms.Telegram.Processing.FormatText`

These prisms are intentionally side-effect free. Use the existing send/edit/reply Telegram prisms for Bot API writes after routing the normalized update.
