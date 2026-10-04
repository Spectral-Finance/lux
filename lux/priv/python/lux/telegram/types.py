"""
Telegram type definitions and Pydantic models for the Lux Framework.

Provides schema validation, serialization, and deserialization for Telegram Bot API
entities including Updates, Messages, CallbackQueries, Entities, and domain-specific
structures such as Threads, Parsed Commands, and Analysis Results.
"""

from __future__ import annotations

import time
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Union
from pydantic import BaseModel, ConfigDict, Field


class ChatType(str, Enum):
    """Telegram chat types."""
    PRIVATE = "private"
    GROUP = "group"
    SUPERGROUP = "supergroup"
    CHANNEL = "channel"


class EntityType(str, Enum):
    """Telegram message entity types."""
    MENTION = "mention"
    HASHTAG = "hashtag"
    CASHTAG = "cashtag"
    BOT_COMMAND = "bot_command"
    URL = "url"
    EMAIL = "email"
    PHONE_NUMBER = "phone_number"
    BOLD = "bold"
    ITALIC = "italic"
    UNDERLINE = "underline"
    STRIKETHROUGH = "strikethrough"
    SPOILER = "spoiler"
    BLOCKQUOTE = "blockquote"
    EXPANDABLE_BLOCKQUOTE = "expandable_blockquote"
    CODE = "code"
    PRE = "pre"
    TEXT_LINK = "text_link"
    TEXT_MENTION = "text_mention"
    CUSTOM_EMOJI = "custom_emoji"


class ParseMode(str, Enum):
    """Telegram text parse modes."""
    MARKDOWN_V2 = "MarkdownV2"
    HTML = "HTML"
    MARKDOWN = "Markdown"
    PLAIN = "Plain"


class UpdateType(str, Enum):
    """Telegram update types."""
    MESSAGE = "message"
    EDITED_MESSAGE = "edited_message"
    CHANNEL_POST = "channel_post"
    EDITED_CHANNEL_POST = "edited_channel_post"
    CALLBACK_QUERY = "callback_query"
    INLINE_QUERY = "inline_query"
    CHOSEN_INLINE_RESULT = "chosen_inline_result"
    POLL = "poll"
    POLL_ANSWER = "poll_answer"
    MY_CHAT_MEMBER = "my_chat_member"
    CHAT_MEMBER = "chat_member"
    CHAT_JOIN_REQUEST = "chat_join_request"
    UNKNOWN = "unknown"


class PermissionLevel(int, Enum):
    """User authorization levels for command routing."""
    USER = 0
    SUBSCRIBER = 10
    MODERATOR = 50
    ADMIN = 80
    SUPERADMIN = 90
    OWNER = 100


class ThreadState(str, Enum):
    """Conversation thread lifecycle states."""
    ACTIVE = "active"
    IDLE = "idle"
    PAUSED = "paused"
    CLOSED = "closed"
    ARCHIVED = "archived"


class IntentCategory(str, Enum):
    """Classified message intent categories."""
    COMMAND = "command"
    QUERY = "query"
    TRANSACTION = "transaction"
    TRADING = "trading"
    WALLET = "wallet"
    HELP = "help"
    SUPPORT = "support"
    FEEDBACK = "feedback"
    GREETING = "greeting"
    SPAM = "spam"
    GENERAL = "general"
    UNKNOWN = "unknown"


class UrgencyLevel(str, Enum):
    """Urgency classification for incoming messages."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class TelegramBaseModel(BaseModel):
    """Base model with standard configuration for Telegram entities."""
    model_config = ConfigDict(
        populate_by_name=True,
        arbitrary_types_allowed=True,
        extra="allow",
        use_enum_values=True,
    )


class User(TelegramBaseModel):
    """Telegram User or Bot representation."""
    id: int
    is_bot: bool = False
    first_name: str
    last_name: Optional[str] = None
    username: Optional[str] = None
    language_code: Optional[str] = None
    is_premium: Optional[bool] = False
    added_to_attachment_menu: Optional[bool] = False
    can_join_groups: Optional[bool] = None
    can_read_all_group_messages: Optional[bool] = None
    supports_inline_queries: Optional[bool] = None

    @property
    def full_name(self) -> str:
        """Returns the full name of the user."""
        if self.last_name:
            return f"{self.first_name} {self.last_name}"
        return self.first_name

    @property
    def mention_tag(self) -> str:
        """Returns @username or markdown link if no username."""
        if self.username:
            return f"@{self.username}"
        return f"[{self.full_name}](tg://user?id={self.id})"


class Chat(TelegramBaseModel):
    """Telegram Chat representation (private, group, supergroup, channel)."""
    id: int
    type: ChatType
    title: Optional[str] = None
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_forum: Optional[bool] = False
    all_members_are_administrators: Optional[bool] = None

    @property
    def is_private(self) -> bool:
        return self.type == ChatType.PRIVATE or self.type == "private"

    @property
    def is_group(self) -> bool:
        return self.type in (ChatType.GROUP, ChatType.SUPERGROUP, "group", "supergroup")


class MessageEntity(TelegramBaseModel):
    """Special entity in a Telegram text message or caption."""
    type: Union[EntityType, str]
    offset: int
    length: int
    url: Optional[str] = None
    user: Optional[User] = None
    language: Optional[str] = None
    custom_emoji_id: Optional[str] = None

    def extract_text(self, full_text: str) -> str:
        """Extracts the slice corresponding to this entity from the source text (UTF-16 safe)."""
        # Telegram API offsets and lengths are in UTF-16 code units
        encoded = full_text.encode("utf-16-le")
        start_byte = self.offset * 2
        end_byte = (self.offset + self.length) * 2
        return encoded[start_byte:end_byte].decode("utf-16-le", errors="ignore")


class WebAppInfo(TelegramBaseModel):
    """Web App information."""
    url: str


class InlineKeyboardButton(TelegramBaseModel):
    """One button of an inline keyboard."""
    text: str
    url: Optional[str] = None
    callback_data: Optional[str] = None
    web_app: Optional[WebAppInfo] = None
    switch_inline_query: Optional[str] = None
    switch_inline_query_current_chat: Optional[str] = None


class InlineKeyboardMarkup(TelegramBaseModel):
    """Inline keyboard markup."""
    inline_keyboard: List[List[InlineKeyboardButton]] = Field(default_factory=list)


class Message(TelegramBaseModel):
    """Telegram Message object."""
    message_id: int
    message_thread_id: Optional[int] = None
    from_user: Optional[User] = Field(default=None, alias="from")
    sender_chat: Optional[Chat] = None
    date: int = 0
    chat: Chat
    forward_from: Optional[User] = None
    forward_from_chat: Optional[Chat] = None
    forward_from_message_id: Optional[int] = None
    forward_date: Optional[int] = None
    is_topic_message: Optional[bool] = False
    reply_to_message: Optional[Message] = None
    via_bot: Optional[User] = None
    edit_date: Optional[int] = None
    text: Optional[str] = None
    entities: Optional[List[MessageEntity]] = None
    caption: Optional[str] = None
    caption_entities: Optional[List[MessageEntity]] = None
    reply_markup: Optional[InlineKeyboardMarkup] = None

    @property
    def effective_text(self) -> str:
        """Returns text or caption or empty string."""
        return self.text or self.caption or ""

    @property
    def effective_entities(self) -> List[MessageEntity]:
        """Returns text entities or caption entities or empty list."""
        return self.entities or self.caption_entities or []


class CallbackQuery(TelegramBaseModel):
    """Incoming callback query from an inline keyboard button."""
    id: str
    from_user: User = Field(..., alias="from")
    message: Optional[Message] = None
    inline_message_id: Optional[str] = None
    chat_instance: Optional[str] = None
    data: Optional[str] = None
    game_short_name: Optional[str] = None


class Update(TelegramBaseModel):
    """Incoming Telegram Update object."""
    update_id: int
    message: Optional[Message] = None
    edited_message: Optional[Message] = None
    channel_post: Optional[Message] = None
    edited_channel_post: Optional[Message] = None
    callback_query: Optional[CallbackQuery] = None

    @property
    def update_type(self) -> UpdateType:
        """Determines the specific update event type."""
        if self.message:
            return UpdateType.MESSAGE
        if self.edited_message:
            return UpdateType.EDITED_MESSAGE
        if self.channel_post:
            return UpdateType.CHANNEL_POST
        if self.edited_channel_post:
            return UpdateType.EDITED_CHANNEL_POST
        if self.callback_query:
            return UpdateType.CALLBACK_QUERY
        return UpdateType.UNKNOWN

    @property
    def effective_user(self) -> Optional[User]:
        """Convenient accessor for the user causing this update."""
        if self.message and self.message.from_user:
            return self.message.from_user
        if self.edited_message and self.edited_message.from_user:
            return self.edited_message.from_user
        if self.callback_query:
            return self.callback_query.from_user
        return None

    @property
    def effective_chat(self) -> Optional[Chat]:
        """Convenient accessor for the chat associated with this update."""
        if self.message:
            return self.message.chat
        if self.edited_message:
            return self.edited_message.chat
        if self.channel_post:
            return self.channel_post.chat
        if self.edited_channel_post:
            return self.edited_channel_post.chat
        if self.callback_query and self.callback_query.message:
            return self.callback_query.message.chat
        return None

    @property
    def effective_message(self) -> Optional[Message]:
        """Convenient accessor for the message in this update."""
        if self.message:
            return self.message
        if self.edited_message:
            return self.edited_message
        if self.channel_post:
            return self.channel_post
        if self.edited_channel_post:
            return self.edited_channel_post
        if self.callback_query:
            return self.callback_query.message
        return None


class ParsedCommand(TelegramBaseModel):
    """Structured representation of a parsed bot command."""
    name: str
    raw_command: str
    bot_username: Optional[str] = None
    subcommand: Optional[str] = None
    args: List[str] = Field(default_factory=list)
    named_args: Dict[str, Any] = Field(default_factory=dict)
    flags: Set[str] = Field(default_factory=set)
    raw_args: str = ""


class ThreadContext(TelegramBaseModel):
    """Conversation thread tracking and state representation."""
    thread_id: str
    chat_id: int
    topic_id: Optional[int] = None
    state: ThreadState = ThreadState.ACTIVE
    created_at: float = Field(default_factory=time.time)
    last_activity_at: float = Field(default_factory=time.time)
    message_count: int = 0
    user_ids: Set[int] = Field(default_factory=set)
    metadata: Dict[str, Any] = Field(default_factory=dict)


class AnalysisResult(TelegramBaseModel):
    """Message analysis outcome."""
    intent: IntentCategory = IntentCategory.UNKNOWN
    confidence: float = 0.0
    sentiment_score: float = 0.0  # -1.0 (very negative) to 1.0 (very positive)
    sentiment_label: str = "neutral"
    urgency: UrgencyLevel = UrgencyLevel.LOW
    urgency_score: float = 0.0
    language: str = "en"
    is_spam: bool = False
    spam_score: float = 0.0
    is_toxic: bool = False
    toxicity_score: float = 0.0
    token_count: int = 0
    char_count: int = 0
    word_count: int = 0
    extracted_entities: Dict[str, List[str]] = Field(default_factory=dict)
    keywords: List[str] = Field(default_factory=list)


class ProcessingResult(TelegramBaseModel):
    """Pipeline execution result."""
    success: bool
    update_id: int
    action_taken: str
    response_payloads: List[Dict[str, Any]] = Field(default_factory=list)
    analysis: Optional[AnalysisResult] = None
    command: Optional[ParsedCommand] = None
    callback_data: Optional[Dict[str, Any]] = None
    errors: List[str] = Field(default_factory=list)
    execution_time_ms: float = 0.0
