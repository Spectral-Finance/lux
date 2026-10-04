# Telegram Message Processing Suite

A production-grade, highly extensible Telegram message processing architecture for the Lux Framework.

## Architecture Overview

The Telegram Message Processing Suite provides an end-to-end framework for ingesting, analyzing, routing, executing, formatting, and responding to Telegram Bot updates. It bridges high-performance Python message parsing, natural language processing, financial entity extraction, and state machine session management with Lux's Elixir Lens, Prism, Beam, Signal, and Agent ecosystem.

```
                    ┌──────────────────────────────────────────────┐
                    │               Telegram Bot API               │
                    └──────────────────────┬───────────────────────┘
                                           │ Updates / Webhook
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 Elixir Integration Layer                                │
│                                                                                        │
│  ┌─────────────────────────┐   ┌───────────────────────────┐   ┌────────────────────┐  │
│  │   Lux.Lenses.Telegram   │   │    Lux.Beams.Telegram     │   │ Lux.Agents.Telegram│  │
│  │   (Message/Command/CB)  │   │  (MessageProcessingBeam)  │   │       Agent        │  │
│  └────────────┬────────────┘   └─────────────┬─────────────┘   └─────────┬──────────┘  │
│               │                              │                           │             │
│  ┌────────────┴──────────────────────────────┴───────────────────────────┴──────────┐  │
│  │                         Lux.Prisms.Telegram Integration                           │  │
│  │   (MessageParserPrism, CommandRouterPrism, FormatConversionPrism, ThreadManager) │  │
│  └───────────────────────────────────────────┬──────────────────────────────────────┘  │
└──────────────────────────────────────────────┼─────────────────────────────────────────┘
                                               │ Venomous Python Bridge
┌──────────────────────────────────────────────▼─────────────────────────────────────────┐
│                                Python Core Suite (`lux.telegram`)                       │
│                                                                                        │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────────────┐  │
│  │       types.py       │  │     analysis.py      │  │         commands.py          │  │
│  │  Pydantic V2 Models  │  │ Intent/Sentiment/NLP │  │ Command Parsing & Middleware │  │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────────────────┘  │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────────────┐  │
│  │     formatter.py     │  │      threads.py      │  │          replies.py          │  │
│  │ MarkdownV2/HTML/Esc  │  │ RingBuffer & LRU TTL │  │ 4096-char Chunking & Framing │  │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────────────────┘  │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────────────┐  │
│  │    deep_links.py     │  │     callbacks.py     │  │         pipeline.py          │  │
│  │  StartPay/HMAC/Auth  │  │ 64B Codec/Pagination │  │   Unified Update Pipeline    │  │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Python Core Components (`lux.telegram`)

### 1. `types.py`
Strongly typed Pydantic V2 models for Telegram objects:
- **`Update`**: Encapsulates incoming Telegram updates, automatic event typing (`UpdateType.MESSAGE`, `UpdateType.CALLBACK_QUERY`, etc.), and accessor helpers (`effective_user`, `effective_chat`, `effective_message`).
- **`Message` & `MessageEntity`**: Strict modeling of text, captions, UTF-16 offset entity extractions (`bot_command`, `url`, `mention`, `cashtag`, `custom_emoji`).
- **`Chat` & `User`**: Private, group, supergroup, channel attributes with permission levels.
- **`ParsedCommand` & `AnalysisResult`**: Normalized representations for commands, intents, entities, sentiment, and urgency.

### 2. `analysis.py`
Message Content Analyzer:
- **Intent Classification**: Classifies messages into `IntentCategory` (TRADING, WALLET, TRANSACTION, QUERY, HELP, SUPPORT, FEEDBACK, GREETING, SPAM, GENERAL).
- **Entity Extraction**:
  - EVM addresses (`0x[a-fA-F0-9]{40}`)
  - Transaction hashes (`0x[a-fA-F0-9]{64}`)
  - Crypto tickers (`$BTC`, `ETH`, `LUX`, `SOL`, `USDT`, etc.)
  - Fiat amounts (`$1,000`, `50 USD`) and crypto amounts (`2.5 ETH`, `100 LUX`)
  - Percentages (`+5.5%`, `-10%`)
  - URLs, mentions (`@user`), hashtags (`#defi`)
- **Sentiment & Urgency Scoring**: Polarity (-1.0 to 1.0) with crypto lexicons (`bullish`, `pump`, `rekt`, `dump`) and urgency levels (LOW, MEDIUM, HIGH, CRITICAL).
- **Spam & Toxicity Filtering**: Detects airdrop scams, phishing links, aggressive promotion, and toxic language.

### 3. `commands.py`
Command Parser & Routing Engine:
- **Argument & Flag Parsing**: Handles positional args, subcommands (`/trade buy ETH 1.0`), long options (`--limit 3200`, `--slippage=0.5`), and short switches (`-f`, `-v`).
- **Type Coercion**: Automatically coerces parameters into `int`, `float`, `bool`, `str`, or validated regex patterns.
- **Permission Levels**: Role-based access control (`USER`, `SUBSCRIBER`, `MODERATOR`, `ADMIN`, `SUPERADMIN`, `OWNER`).
- **Middleware Lifecycle**: Supports `add_pre_middleware`, `add_post_middleware`, and `add_error_handler`.
- **Dynamic Help Generator**: Automatically generates formatted documentation for all registered commands.

### 4. `formatter.py`
Bidirectional Telegram Formatter:
- **MarkdownV2 Escaping**: Full escaping of all 18 reserved characters (`_*[]()~`>#+-=|{}.!`) with dedicated link and code block isolation.
- **HTML Escaping & Conversion**: Converts standard Markdown to Telegram HTML (`<b>`, `<i>`, `<code>`, `<pre>`, `<blockquote>`, `<tg-spoiler>`) and bidirectional conversion between Telegram HTML and MarkdownV2.
- **Plain Text Stripping**: Strips formatting tags while preserving clean link representations.
- **ASCII Table Formatter**: Produces aligned monospace ASCII tables.

### 5. `threads.py`
Conversation & Thread Session Management:
- **Thread Context**: Supports forum topic IDs (`message_thread_id`) and private/group chat IDs.
- **Ring Buffer History**: Configurable ring buffer keeping the last N messages per conversation.
- **LRU Session Cache & TTL**: Automatically purges expired sessions and bounds memory consumption.
- **Context Window Trimming**: Intelligent token-budget trimming for LLM context windows while preserving system prompts and recent context.
- **State Machine**: Transitions across `ACTIVE`, `IDLE`, `PAUSED`, `CLOSED`, and `ARCHIVED`.

### 6. `replies.py`
Reply Hierarchy & Message Splitting:
- **Reply Tree Tracking**: Traces parent-child message hierarchies and root message IDs.
- **Quote Formatting**: Generates blockquote snippets with sender attribution.
- **Safe 4096-Character Splitter**: Chunks long messages without breaking code blocks (properly closes and reopens code fences across chunk boundaries) or splitting sentences mid-word.
- **Error Notification Cards**: Standardized error cards with error codes, actionable guidance, and inline retry buttons.

### 7. `deep_links.py`
Deep Linking & Mini App Entrypoints:
- **Payload Parsing**: Handles `t.me/Bot?start=PAYLOAD` and `startapp=PAYLOAD`.
- **Parameter Serialization**: Encodes/decodes referral IDs, campaigns, auth tokens, and trade parameters.
- **Cryptographic Security**: HMAC-SHA256 signature verification to prevent payload tampering.
- **Compression**: zlib + base64url payload compression for large parameter objects.

### 8. `callbacks.py`
Inline Keyboard Callbacks & Pagination:
- **64-Byte Constraint Codec**: Efficient compact parameter encoding (`action:target:id`).
- **Pagination Navigation**: Generates pagination rows: `[⏮ 1] [◀ Prev] [· 3/10 ·] [Next ▶] [⏭ 10]`.
- **Answer Formatter**: Builds `answerCallbackQuery` responses with toast notifications and alert dialogs.

### 9. `pipeline.py`
Unified Update Pipeline:
- Orchestrates update normalization, event dispatch, deep links, command routing, callback handling, thread history recording, response formatting, and chunking into Telegram Bot API payloads.

---

## Elixir Integration Layer (`lux/lib/lux/`)

### Lenses (`Lux.Lenses.Telegram`)
- `MessageLens`: Focuses on polling updates via `/getUpdates`.
- `CommandLens`: Fetches configured bot commands via `/getMyCommands`.
- `CallbackLens`: Dispatches acknowledgments via `/answerCallbackQuery`.

### Prisms (`Lux.Prisms.Telegram`)
- `MessageParserPrism`: Runs natural language analysis and financial entity extraction on messages.
- `CommandRouterPrism`: Parses and validates bot commands and parameters.
- `FormatConversionPrism`: Converts between MarkdownV2, HTML, and Plain text.
- `ThreadManagerPrism`: Manages session context windows and history trimming for LLM agents.
- `CallbackQueryPrism`: Decodes and processes inline keyboard queries.

### Beams & Signals (`Lux.Beams.Telegram`, `Lux.Signals.Telegram`)
- `MessageProcessingBeam`: End-to-end processing pipeline beam.
- `TelegramMessageSignal`, `TelegramCommandSignal`, `TelegramCallbackSignal`: Type-safe schema-validated Lux signals.

### Agent (`Lux.Agents.TelegramAgent`)
- Autonomous Telegram Agent coordinating conversation reasoning, command execution, and signal handling.

---

## Python Usage Examples

### 1. Analyzing a Message
```python
from lux.telegram.analysis import MessageAnalyzer

analyzer = MessageAnalyzer()
result = analyzer.analyze("Buying 2.5 ETH at $3,500 on market order. Super bullish!")

print(result.intent)             # "trading"
print(result.sentiment_label)    # "positive"
print(result.extracted_entities) # {'crypto_tickers': ['ETH'], 'crypto_amounts': ['2.5 ETH'], 'fiat_amounts': ['$3,500'], ...}
```

### 2. Creating and Routing Commands
```python
from lux.telegram.commands import CommandRouter, CommandContext, CommandOption, PermissionLevel

router = CommandRouter(bot_username="LuxBot")

@router.command("swap", description="Swap tokens", options=[
    CommandOption(name="amount", type=float, required=True),
    CommandOption(name="from_token", required=True),
    CommandOption(name="to_token", required=True),
    CommandOption(name="slippage", type=float, default=0.5)
])
def handle_swap(ctx: CommandContext):
    opts = ctx.command.named_args
    return f"Swapping {opts['amount']} {opts['from_token']} to {opts['to_token']} (slippage: {opts['slippage']}%)"
```

### 3. Formatting Text & Tables
```python
from lux.telegram.formatter import TelegramFormatter, ParseMode

text = TelegramFormatter.bold("Spectral Finance", parse_mode=ParseMode.MARKDOWN_V2)
table = TelegramFormatter.format_table(
    headers=["Asset", "Price", "24h"],
    rows=[["ETH", "$3,500", "+4.2%"], ["BTC", "$68,000", "+2.1%"]]
)
```

---

## Testing & Verification

Execute test suites via pytest:
```powershell
cd lux/priv/python
python -m pytest tests/telegram -v
```

100% test pass rate with full coverage across all modules.
