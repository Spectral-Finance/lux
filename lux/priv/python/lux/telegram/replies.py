"""
Reply management, message chunking, quote formatting, and structured response framing.

Implements Telegram's 4096-character limit safe chunking with code-block preservation,
reply tree tracking, quote generation, and standardized error/status notification cards.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from lux.telegram.formatter import TelegramFormatter
from lux.telegram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    Message,
    ParseMode,
)

# Telegram Bot API limits
MAX_MESSAGE_LENGTH = 4096
MAX_CAPTION_LENGTH = 1024


@dataclass
class ReplyNode:
    """Node in a conversation reply chain."""
    message_id: int
    sender_id: int
    sender_name: str
    text: str
    parent_id: Optional[int] = None
    children: List[ReplyNode] = field(default_factory=list)


class ReplyManager:
    """Production manager for message replies, smart chunking, and structured cards."""

    def __init__(self):
        self._nodes: Dict[int, ReplyNode] = {}

    def track_reply(self, message: Message) -> ReplyNode:
        """Records a message and links it to its reply parent if present."""
        user_id = message.from_user.id if message.from_user else 0
        user_name = message.from_user.full_name if message.from_user else "User"
        parent_id = message.reply_to_message.message_id if message.reply_to_message else None

        node = ReplyNode(
            message_id=message.message_id,
            sender_id=user_id,
            sender_name=user_name,
            text=message.effective_text,
            parent_id=parent_id,
        )
        self._nodes[message.message_id] = node

        if parent_id and parent_id in self._nodes:
            self._nodes[parent_id].children.append(node)

        return node

    def get_root_message_id(self, message_id: int) -> int:
        """Traverses upwards through parents to find the original conversation root ID."""
        curr_id = message_id
        visited = set()
        while curr_id in self._nodes and curr_id not in visited:
            visited.add(curr_id)
            node = self._nodes[curr_id]
            if node.parent_id and node.parent_id in self._nodes:
                curr_id = node.parent_id
            else:
                break
        return curr_id

    def get_reply_depth(self, message_id: int) -> int:
        """Calculates the depth of this message in the reply chain."""
        depth = 0
        curr_id = message_id
        visited = set()
        while curr_id in self._nodes and curr_id not in visited:
            visited.add(curr_id)
            node = self._nodes[curr_id]
            if node.parent_id and node.parent_id in self._nodes:
                depth += 1
                curr_id = node.parent_id
            else:
                break
        return depth

    @classmethod
    def generate_quote(
        cls,
        text: str,
        author: Optional[str] = None,
        max_length: int = 150,
        parse_mode: ParseMode = ParseMode.MARKDOWN_V2,
    ) -> str:
        """Formats a blockquote snippet with optional author header and truncation."""
        if not text:
            return ""

        clean_text = text.strip().replace("\n", " ")
        if len(clean_text) > max_length:
            clean_text = clean_text[: max_length - 3] + "..."

        if author:
            quote_str = f"{author}: {clean_text}"
        else:
            quote_str = clean_text

        return TelegramFormatter.blockquote(quote_str, parse_mode=parse_mode)

    @classmethod
    def split_message(
        cls,
        text: str,
        max_limit: int = MAX_MESSAGE_LENGTH,
        parse_mode: ParseMode = ParseMode.MARKDOWN_V2,
    ) -> List[str]:
        """Safely splits a long text into chunks <= max_limit.

        Preserves code fences across chunks, respects line breaks, paragraphs,
        and sentences, and avoids broken tags.
        """
        if not text:
            return []

        if len(text) <= max_limit:
            return [text]

        chunks: List[str] = []
        remaining = text
        in_code_block = False
        code_block_lang = ""

        while remaining:
            if len(remaining) <= max_limit and not in_code_block:
                chunks.append(remaining)
                break

            # Effective budget considering opening/closing fences if in code block
            fence_overhead = (len(code_block_lang) + 10) if in_code_block else 0
            budget = max(50, max_limit - fence_overhead - 20)

            split_idx = cls._find_split_point(remaining, budget)
            raw_chunk = remaining[:split_idx].rstrip()
            remaining = remaining[split_idx:].lstrip("\r\n")

            if in_code_block:
                # Prepend opening fence
                prefix = f"```{code_block_lang}\n"
                # Check if raw_chunk has closing fence
                if "```" in raw_chunk:
                    in_code_block = False
                    chunk = prefix + raw_chunk
                else:
                    # Still in code block, close temporarily
                    chunk = prefix + raw_chunk + "\n```"
            else:
                # Check if raw_chunk opens a code block
                matches = list(re.finditer(r"```([a-zA-Z0-9_]*)", raw_chunk))
                if len(matches) % 2 != 0:
                    # Opens code block without closing it
                    in_code_block = True
                    code_block_lang = matches[-1].group(1)
                    chunk = raw_chunk + "\n```"
                else:
                    chunk = raw_chunk

            chunks.append(chunk)

        return chunks

    @classmethod
    def _find_split_point(cls, text: str, target: int) -> int:
        """Finds the most natural boundary (paragraph, line, sentence, space) before target."""
        if len(text) <= target:
            return len(text)

        slice_text = text[:target]

        # 1. Paragraph break
        last_para = slice_text.rfind("\n\n")
        if last_para > target // 2:
            return last_para + 2

        # 2. Line break
        last_line = slice_text.rfind("\n")
        if last_line > target // 2:
            return last_line + 1

        # 3. Sentence end (.!?)
        sentence_ends = [m.end() for m in re.finditer(r"[\.!\?]\s+", slice_text)]
        if sentence_ends and sentence_ends[-1] > target // 3:
            return sentence_ends[-1]

        # 4. Word boundary
        last_space = slice_text.rfind(" ")
        if last_space > target // 4:
            return last_space + 1

        # Fallback hard slice
        return target

    @classmethod
    def frame_response(
        cls,
        body: str,
        title: Optional[str] = None,
        footer: Optional[str] = None,
        status_icon: Optional[str] = None,
        quote: Optional[str] = None,
        parse_mode: ParseMode = ParseMode.MARKDOWN_V2,
    ) -> str:
        """Frames a structured response message with title, quote, body, and footer."""
        sections: List[str] = []

        if title:
            icon = f"{status_icon} " if status_icon else ""
            bold_title = TelegramFormatter.bold(f"{icon}{title}", parse_mode=parse_mode)
            sections.append(bold_title)

        if quote:
            sections.append(quote)

        if body:
            sections.append(body)

        if footer:
            italic_footer = TelegramFormatter.italic(footer, parse_mode=parse_mode)
            sections.append(f"—\n{italic_footer}")

        return "\n\n".join(sections)

    @classmethod
    def create_error_response(
        cls,
        error_message: str,
        error_code: Optional[str] = None,
        suggestion: Optional[str] = None,
        retry_callback_data: Optional[str] = None,
        parse_mode: ParseMode = ParseMode.MARKDOWN_V2,
    ) -> Tuple[str, Optional[InlineKeyboardMarkup]]:
        """Generates a standardized error response and optional retry keyboard markup."""
        code_tag = f" [{error_code}]" if error_code else ""
        title = f"Error{code_tag}"
        body_lines = [TelegramFormatter.escape_markdown_v2(error_message) if parse_mode == ParseMode.MARKDOWN_V2 else error_message]

        if suggestion:
            body_lines.append("\n💡 " + (TelegramFormatter.escape_markdown_v2(suggestion) if parse_mode == ParseMode.MARKDOWN_V2 else suggestion))

        body = "\n".join(body_lines)
        framed = cls.frame_response(
            body=body,
            title=title,
            status_icon="⚠️",
            footer="Need help? Contact support or type /help",
            parse_mode=parse_mode,
        )

        markup = None
        if retry_callback_data:
            markup = InlineKeyboardMarkup(
                inline_keyboard=[
                    [
                        InlineKeyboardButton(
                            text="🔄 Retry",
                            callback_data=retry_callback_data,
                        ),
                        InlineKeyboardButton(
                            text="❓ Help",
                            callback_data="help:general",
                        ),
                    ]
                ]
            )

        return framed, markup
