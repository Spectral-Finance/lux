# Telegram Message Processing

`Lux.Integrations.Telegram.MessageProcessor` converts raw Telegram Bot API updates into
agent-ready routing data without making network calls.

```elixir
{:ok, processed} =
  Lux.Prisms.Telegram.Messaging.ProcessUpdate.run(%{
    update: %{
      "update_id" => 100,
      "message" => %{
        "message_id" => 7,
        "message_thread_id" => 42,
        "text" => "/trade@LuxBot symbol=ETH side=long",
        "chat" => %{"id" => -100, "type" => "supergroup"},
        "from" => %{"id" => 1, "username" => "alice"}
      }
    },
    bot_username: "LuxBot"
  })

processed.command.command
processed.command.args
processed.formatting.markdown_v2
```

The processor covers:

- update classification for messages, edited messages, channel posts, callback queries,
  inline queries, polls, chat member updates, and join requests;
- message type detection for text and media messages;
- slash-command parsing with optional bot mentions and `key=value` arguments;
- MarkdownV2 and HTML escaping helpers;
- thread and reply context extraction;
- `/start` deep-link payload parsing;
- callback query data decoding;
- route suggestions for command, callback, reply, channel post, and generic message handling.
