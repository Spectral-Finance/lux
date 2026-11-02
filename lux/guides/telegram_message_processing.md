# Telegram Message Processing in Lux

## Overview

The `Lux.Integrations.Telegram.MessageProcessing` suite provides a complete, production-grade pipeline for parsing, transforming, routing, and formatting Telegram messages. It is built to support the Telegram Bot API 7.0+ specifications, including:

- Full message classification across all message types (text, media, location, polls, service events)
- Command parsing with quote-aware arguments and GNU-style options (`--flag=value`, `-v`)
- Command routing engine with permission guards and chat-type constraints
- Format conversion utilities between Plain Text, HTML, Markdown, and MarkdownV2
- Telegram entity parsing and formatting reconstruction
- Forum topic and thread management (`message_thread_id`, supergroup topics)
- Telegram Bot API 7.0+ quote replies and reply context generation
- Deep link handling (`/start <payload>`, referral codes, auth tokens, mini-apps)
- Callback query processing with packed 64-byte codecs and alert answering
- Dedicated Prisms and the `Lux.Beams.Telegram.MessageProcessingBeam` pipeline

---

## Architecture

```
                       +---------------------------------------+
                       |        Telegram Update / Webhook       |
                       +---------------------------------------+
                                           |
                                           v
                       +---------------------------------------+
                       |   MessageProcessingBeam Pipeline      |
                       +---------------------------------------+
                                           |
        +----------------------------------+----------------------------------+
        |                                  |                                  |
        v                                  v                                  v
+------------------+             +--------------------+            +--------------------+
| ContentAnalyzer  |             |   ThreadManager    |            |   ReplyManager     |
| - Type detection |             | - Forum topic ID   |            | - Quote resolution |
| - Text stats     |             | - General vs custom|            | - Reply chains     |
| - Media metadata |             | - Topic events     |            | - API 7.0+ quote   |
+------------------+             +--------------------+            +--------------------+
        |                                  |                                  |
        +----------------------------------+----------------------------------+
                                           |
        +----------------------------------+----------------------------------+
        |                                                                     |
        v                                                                     v
+------------------+                                                +--------------------+
|  CommandParser   |                                                | CallbackProcessor  |
| - Tokenizer      |                                                | - Action routing   |
| - Quotes & flags |                                                | - 64-byte codec    |
| - Bot filtering  |                                                | - Alert builder    |
+------------------+                                                +--------------------+
        |
        v
+------------------+
|  CommandRouter   |
| - Permission chk |
| - Chat type chk  |
| - Dispatcher     |
+------------------+
        |
        v
+------------------+
| FormatConverter  |
| - Markdown/HTML  |
| - Escapers       |
| - 4096-char chunk|
+------------------+
```

---

## 1. Message Content Analysis

The `ContentAnalyzer` inspects raw Telegram messages and classifies them into structured types:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.ContentAnalyzer

{:ok, analysis} = ContentAnalyzer.analyze(telegram_message)

analysis.message_type
#=> :text | :photo | :video | :document | :location | :poll | :contact ...

analysis.text_stats
#=> %{char_count: 120, word_count: 18, line_count: 3, estimated_tokens: 30, has_commands: true}

analysis.media_info
#=> %{type: :photo, file_id: "...", width: 1280, height: 720, caption: "Chart"}

analysis.flags
#=> %{is_forwarded: false, is_reply: true, is_topic_message: true, has_media: true}
```

---

## 2. Command Parsing & Routing

### Command Parsing

`CommandParser` handles bot tags, single/double quoted strings with escaped characters, positional arguments, and GNU-style options:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.CommandParser

# Input command:
text = ~s(/trade buy "Ethereum Mainnet" 2.5 --slippage=0.5 --dry-run -v)

{:ok, cmd} = CommandParser.parse(text, bot_username: "LuxTraderBot")

cmd.command #=> "trade"
cmd.args    #=> ["buy", "Ethereum Mainnet", 2.5]
cmd.options #=> %{slippage: 0.5, dry_run: true, v: true}
```

### Command Routing

`CommandRouter` manages route registration, permissions, and chat constraints:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.CommandRouter

router =
  CommandRouter.new()
  |> CommandRouter.register("balance", &handle_balance/2,
    description: "Check current wallet balance",
    usage: "/balance [symbol]",
    chat_types: [:private, :group, :supergroup]
  )
  |> CommandRouter.register("withdraw", &handle_withdraw/2,
    description: "Withdraw funds to external wallet",
    permissions: [:admin, :owner],
    chat_types: [:private]
  )

# Dispatch command with context
context = %{user_id: 12345, chat_type: :supergroup, is_admin: false}
{:error, {:chat_type_not_allowed, :supergroup}} = CommandRouter.dispatch(router, withdraw_cmd, context)

# Generate BotFather menu list
botfather_text = CommandRouter.format_botfather_commands(router)
#=> balance - Check current wallet balance
#=> withdraw - Withdraw funds to external wallet
```

---

## 3. Format Conversion & Escaping

Telegram supports HTML, Markdown (legacy), and MarkdownV2. `FormatConverter` safely handles escaping and tag conversions:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.FormatConverter

# HTML escaping:
FormatConverter.escape_html("<script>alert('xss');</script>")
#=> "&lt;script&gt;alert('xss');&lt;/script&gt;"

# MarkdownV2 escaping (escapes all 18 special characters):
FormatConverter.escape_markdown_v2("Price: $100.00! [ETH-USDC] #crypto")
#=> "Price: \\$100\\.00\\! \\[ETH\\-USDC\\] \\#crypto"

# Markdown to Telegram HTML conversion:
FormatConverter.markdown_to_html("*Bold* text with `code` and ||spoiler||")
#=> "<b>Bold</b> text with <code>code</code> and <tg-spoiler>spoiler</tg-spoiler>"

# Message chunking (max 4096 characters):
chunks = FormatConverter.chunk_message(long_text, 4096)
```

---

## 4. Forum Topics & Thread Management

Telegram forum supergroups use `message_thread_id` to route conversations into dedicated topics:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.ThreadManager

# Extract thread context
info = ThreadManager.extract_thread_info(message)
info.is_thread         #=> true
info.thread_id         #=> 42
info.is_general_topic  #=> false

# Build response parameters targeting the same thread
reply_params = ThreadManager.build_thread_reply_params(message, quote_reply: true)
#=> %{
#     chat_id: -1001234567,
#     message_thread_id: 42,
#     reply_parameters: %{message_id: 890, allow_sending_without_reply: true}
#   }
```

---

## 5. Reply Management & Bot API 7.0+ Quotes

`ReplyManager` extracts replied messages and handles quote selections:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.ReplyManager

{:ok, reply_info} = ReplyManager.resolve_reply(message)
reply_info.replied_message_id #=> 1024
reply_info.replied_text       #=> "Should we swap to USDC?"
reply_info.quote              #=> %{text: "swap to USDC", position: 10, is_manual: true}

# Formats conversation prompt with quoted context for LLM agents
prompt_context = ReplyManager.format_llm_context(message)
#=> "> [Quoted]: swap to USDC\n\nYes, execute swap immediately."
```

---

## 6. Deep Linking

Handles referral tracking, authentication tokens, and Mini-App parameters adhering to the 64-character limit:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.DeepLinkHandler

# Parse incoming /start payload:
{:ok, data} = DeepLinkHandler.parse("/start ref_partner_99")
data.type #=> :referral
data.code #=> "partner_99"

# Generate deep link:
{:ok, url} = DeepLinkHandler.generate_link("LuxAgentBot", "ref_partner_99", type: :bot)
#=> "https://t.me/LuxAgentBot?start=ref_partner_99"

# Mini-App deep link:
{:ok, app_url} = DeepLinkHandler.generate_link("LuxAgentBot", "ref_partner_99", type: :mini_app, app_name: "swap")
#=> "https://t.me/LuxAgentBot/swap?startapp=ref_partner_99"
```

---

## 7. Callback Query Processing

Handles inline keyboard clicks, encodes/decodes callback payloads within 64 bytes, and generates answer notifications:

```elixir
alias Lux.Integrations.Telegram.MessageProcessing.CallbackQueryProcessor

# Encode structured data
{:ok, data} = CallbackQueryProcessor.encode_data("vote", ["proposal_1", "yes"])
#=> "vote:proposal_1:yes"

# Parse incoming query
{:ok, parsed} = CallbackQueryProcessor.parse(callback_query)
parsed.action #=> "vote"
parsed.args   #=> ["proposal_1", "yes"]

# Build response to answerCallbackQuery
answer = CallbackQueryProcessor.build_answer(parsed.id,
  text: "Vote recorded!",
  show_alert: false
)
```

---

## 8. Specialized Prisms & Beams

The following Prisms are available:

| Prism | Module | Description |
|---|---|---|
| `AnalyzeContent` | `Lux.Prisms.Telegram.MessageProcessing.AnalyzeContent` | Classifies message type, extracts sender/chat and metadata |
| `ParseCommand` | `Lux.Prisms.Telegram.MessageProcessing.ParseCommand` | Extracts command name, args, and GNU-style options |
| `RouteCommand` | `Lux.Prisms.Telegram.MessageProcessing.RouteCommand` | Dispatches command through registered permission-guarded routes |
| `FormatMessage` | `Lux.Prisms.Telegram.MessageProcessing.FormatMessage` | Converts and chunks messages into Telegram HTML/MarkdownV2 |
| `ManageThread` | `Lux.Prisms.Telegram.MessageProcessing.ManageThread` | Resolves forum topic thread IDs and builds thread reply parameters |
| `ResolveReply` | `Lux.Prisms.Telegram.MessageProcessing.ResolveReply` | Resolves replied messages and API 7.0+ quotes |
| `HandleDeepLink` | `Lux.Prisms.Telegram.MessageProcessing.HandleDeepLink` | Decodes start payloads and generates Telegram URLs |
| `ProcessCallbackQuery` | `Lux.Prisms.Telegram.MessageProcessing.ProcessCallbackQuery` | Unpacks inline callback queries and formats answers |

### MessageProcessingBeam Pipeline

Orchestrates message processing from end to end:

```elixir
alias Lux.Beams.Telegram.MessageProcessingBeam

{:ok, result} = MessageProcessingBeam.process_message(incoming_update_message, bot_username: "LuxTraderBot")

result.analysis        # Content analysis & message type
result.thread_context  # Forum topic thread parameters
result.reply_context   # Reply hierarchy and quotes
result.command_context # Parsed command arguments and flags
```
