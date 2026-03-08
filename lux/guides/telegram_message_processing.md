# Telegram Message Processing Guide

Advanced message handling, command routing, formatting, threads, callbacks, and deep links.

## Message Parser

```elixir
# Parse any incoming message
{:ok, result} = MessageParser.handler(%{message: update["message"]}, nil)
# result.type => :text | :photo | :video | :document | :sticker | ...
# result.entities => [%{type: "mention", value: "@bot", ...}]
# result.metadata => %{chat_id: -100, reply_to_message_id: 99, ...}
```

## Command Router

```elixir
# Parse /command@bot arg1 key=value
{:ok, cmd} = CommandRouter.handler(%{text: "/ban@mybot user123 reason=spam"}, nil)
# cmd.command => "/ban"
# cmd.bot => "mybot"
# cmd.args => ["user123"]
# cmd.params => %{"reason" => "spam"}

# Filter by bot username
CommandRouter.parse_command("/help@otherbot", "mybot")
# => :not_a_command

# Deep link: /start base64payload
CommandRouter.parse_command("/start #{Base.url_encode64("ref_abc123")}")
# => %{deep_link: %{raw: "...", decoded: "ref_abc123"}}
```

## Message Formatter

```elixir
# Build formatted text
MessageFormatter.bold("important", :html)        # => "<b>important</b>"
MessageFormatter.bold("important", :markdownv2)   # => "*important*"
MessageFormatter.code("x = 1", :html)             # => "<code>x = 1</code>"
MessageFormatter.spoiler("secret", :html)          # => "<tg-spoiler>secret</tg-spoiler>"
MessageFormatter.link("click", "https://...", :html) # => "<a href=\"...\">click</a>"

# Escape for safe sending
MessageFormatter.escape_html("<script>alert(1)</script>")
MessageFormatter.escape_mdv2("hello_world")

# Strip all formatting
MessageFormatter.strip_formatting("<b>bold</b> *md*") # => "bold md"
```

## Thread Manager (Forum Topics)

```elixir
ThreadManager.handler(%{action: "create_topic", token: t, chat_id: id, name: "Discussion"}, nil)
ThreadManager.handler(%{action: "close_topic", token: t, chat_id: id, message_thread_id: 42}, nil)
ThreadManager.handler(%{action: "reopen_topic", token: t, chat_id: id, message_thread_id: 42}, nil)
ThreadManager.handler(%{action: "delete_topic", token: t, chat_id: id, message_thread_id: 42}, nil)
```

## Callback Query Handler

```elixir
# Answer callback
CallbackQueryHandler.handler(%{action: "answer", token: t, callback_query_id: "123", text: "Done!"}, nil)

# Parse structured callback data
CallbackQueryHandler.parse_callback_data(%{callback_data: "vote:option:3"})
# => %{action: "vote", args: ["option", "3"], format: :colon}

CallbackQueryHandler.parse_callback_data(%{callback_data: "settings|lang=en|theme=dark"})
# => %{action: "settings", params: %{"lang" => "en", "theme" => "dark"}, format: :pipe}

# Edit originating message
CallbackQueryHandler.handler(%{action: "edit_message", token: t, chat_id: id, message_id: 456, text: "Updated!"}, nil)
```

## Deep Link Handler

```elixir
# Decode deep link payload (auto base64 detection)
DeepLinkHandler.handler(%{payload: Base.url_encode64("ref_code-abc123")}, nil)
# => %{action: "ref", is_referral: true, referral_code: "abc123"}

# Group deep links
DeepLinkHandler.handler(%{payload: "setup_config", type: "startgroup"}, nil)
```
