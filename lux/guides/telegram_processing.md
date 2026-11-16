# Telegram Message Processing in Lux

Lux provides specialized Prisms to handle the complexities of the Telegram Bot API.

## Core Components

### 1. Parser Prism
The `Lux.Prisms.Telegram.Parser` converts raw JSON updates from Telegram into a normalized map. It supports:
- Text messages
- Media (Photos, Documents)
- Callback Queries (from Inline Keyboards)
- Edited messages

### 2. Command Parsing
Use `Lux.Prisms.Telegram.CommandHandler` to route logic based on user commands.
```elixir
{:ok, command, args} = CommandHandler.parse_command(message.text)
```

### 3. Formatting
Telegram requires strict escaping for `MarkdownV2`. The `Formatter` utility ensures your agent's responses don't trigger 400 Bad Request errors.
```elixir
safe_text = Formatter.escape_markdown_v2("User input with dots...")
```

### 4. Threading & Replies
The `ThreadManager` helps maintain context in group chats or topics (Forum mode).
```elixir
payload = ThreadManager.build_reply_payload(chat_id, "Response", original_msg_id, thread_id)
```

## Example Usage in an Agent
```elixir
def handle_signal(%{source: :telegram, data: raw_update}) do
  parsed = Lux.Prisms.Telegram.Parser.parse(raw_update)
  
  case Lux.Prisms.Telegram.CommandHandler.parse_command(parsed.text) do
    {:ok, "analyze", [target]} -> 
       # Trigger analysis logic
    _ -> 
       # Default handling
  end
end
