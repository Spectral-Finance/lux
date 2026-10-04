"""
Bidirectional text formatting and escaping engine for Telegram Bot API.

Implements strict escaping specifications for Telegram MarkdownV2, Telegram HTML,
and Plain Text. Supports format conversions, inline entity tags, code block
isolation, and structured ASCII table generation.
"""

from __future__ import annotations

import html
import re
from typing import Any, List, Optional, Union

from lux.telegram.types import ParseMode


class TelegramFormatter:
    """Production formatter for Telegram MarkdownV2, HTML, and Plain Text."""

    # All 18 characters that must be escaped in MarkdownV2 outside formatting tags:
    # '_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!'
    MARKDOWN_V2_SPECIAL_CHARS = re.compile(r"([_\*\[\]\(\)~`>#\+\-=\|{}\.!])")

    # Characters that must be escaped inside inline links / mentions:
    MARKDOWN_V2_LINK_CHARS = re.compile(r"([\)\\])")

    # Characters that must be escaped inside pre/code blocks:
    MARKDOWN_V2_CODE_CHARS = re.compile(r"([`\\])")

    @classmethod
    def escape_markdown_v2(cls, text: str, as_link_url: bool = False, as_code: bool = False) -> str:
        """Escapes text for Telegram MarkdownV2 according to official API rules."""
        if not text:
            return ""

        str_val = str(text)

        if as_code:
            return cls.MARKDOWN_V2_CODE_CHARS.sub(r"\\\1", str_val)
        if as_link_url:
            return cls.MARKDOWN_V2_LINK_CHARS.sub(r"\\\1", str_val)

        return cls.MARKDOWN_V2_SPECIAL_CHARS.sub(r"\\\1", str_val)

    @classmethod
    def escape_html(cls, text: str) -> str:
        """Escapes special characters (&, <, >, ") for Telegram HTML parse mode."""
        if not text:
            return ""
        return html.escape(str(text), quote=True)

    @classmethod
    def bold(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats text as bold."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            return f"*{cls.escape_markdown_v2(text)}*"
        if mode == ParseMode.HTML:
            return f"<b>{cls.escape_html(text)}</b>"
        if mode == ParseMode.MARKDOWN:
            return f"*{text}*"
        return text

    @classmethod
    def italic(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats text as italic."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            return f"_{cls.escape_markdown_v2(text)}_"
        if mode == ParseMode.HTML:
            return f"<i>{cls.escape_html(text)}</i>"
        if mode == ParseMode.MARKDOWN:
            return f"_{text}_"
        return text

    @classmethod
    def underline(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats text as underlined."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            return f"__{cls.escape_markdown_v2(text)}__"
        if mode == ParseMode.HTML:
            return f"<u>{cls.escape_html(text)}</u>"
        return text

    @classmethod
    def strikethrough(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats text as strikethrough."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            return f"~{cls.escape_markdown_v2(text)}~"
        if mode == ParseMode.HTML:
            return f"<s>{cls.escape_html(text)}</s>"
        return text

    @classmethod
    def spoiler(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats text with spoiler overlay."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            return f"||{cls.escape_markdown_v2(text)}||"
        if mode == ParseMode.HTML:
            return f"<tg-spoiler>{cls.escape_html(text)}</tg-spoiler>"
        return text

    @classmethod
    def code(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats inline monospace code."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            return f"`{cls.escape_markdown_v2(text, as_code=True)}`"
        if mode == ParseMode.HTML:
            return f"<code>{cls.escape_html(text)}</code>"
        if mode == ParseMode.MARKDOWN:
            return f"`{text}`"
        return text

    @classmethod
    def pre(
        cls,
        text: str,
        language: Optional[str] = None,
        parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2,
    ) -> str:
        """Formats multi-line preformatted code block."""
        mode = ParseMode(parse_mode)
        lang_tag = language or ""

        if mode == ParseMode.MARKDOWN_V2:
            escaped_code = cls.escape_markdown_v2(text, as_code=True)
            return f"```{lang_tag}\n{escaped_code}\n```"
        if mode == ParseMode.HTML:
            escaped_code = cls.escape_html(text)
            if language:
                return f'<pre><code class="language-{cls.escape_html(language)}">{escaped_code}</code></pre>'
            return f"<pre>{escaped_code}</pre>"
        if mode == ParseMode.MARKDOWN:
            return f"```{lang_tag}\n{text}\n```"
        return text

    @classmethod
    def link(cls, text: str, url: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Formats an inline hyperlink."""
        mode = ParseMode(parse_mode)
        if mode == ParseMode.MARKDOWN_V2:
            escaped_text = cls.escape_markdown_v2(text)
            escaped_url = cls.escape_markdown_v2(url, as_link_url=True)
            return f"[{escaped_text}]({escaped_url})"
        if mode == ParseMode.HTML:
            return f'<a href="{cls.escape_html(url)}">{cls.escape_html(text)}</a>'
        if mode == ParseMode.MARKDOWN:
            return f"[{text}]({url})"
        return f"{text} ({url})"

    @classmethod
    def mention(
        cls,
        user_id: int,
        name: str,
        parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2,
    ) -> str:
        """Formats an inline mention linking to user ID."""
        url = f"tg://user?id={user_id}"
        return cls.link(name, url, parse_mode=parse_mode)

    @classmethod
    def blockquote(
        cls,
        text: str,
        expandable: bool = False,
        parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2,
    ) -> str:
        """Formats a blockquote (single or expandable)."""
        mode = ParseMode(parse_mode)
        lines = text.split("\n")

        if mode == ParseMode.MARKDOWN_V2:
            prefix = "**>" if expandable else ">"
            escaped_lines = [f"{prefix}{cls.escape_markdown_v2(line)}" for line in lines]
            return "\n".join(escaped_lines)
        if mode == ParseMode.HTML:
            tag = "blockquote"
            attr = ' expandable=""' if expandable else ""
            escaped_content = cls.escape_html(text)
            return f"<{tag}{attr}>{escaped_content}</{tag}>"
        return "\n".join(f"> {line}" for line in lines)

    @classmethod
    def format_table(
        cls,
        headers: List[str],
        rows: List[List[Any]],
        parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2,
    ) -> str:
        """Formats a structured ASCII table aligned in a monospace block."""
        if not headers and not rows:
            return ""

        num_cols = max(len(headers), max((len(r) for r in rows), default=0))
        padded_headers = list(headers) + [""] * (num_cols - len(headers))

        col_widths = [len(str(h)) for h in padded_headers]

        string_rows: List[List[str]] = []
        for row in rows:
            padded_row = [str(item) for item in row] + [""] * (num_cols - len(row))
            string_rows.append(padded_row)
            for i, val in enumerate(padded_row):
                col_widths[i] = max(col_widths[i], len(val))

        header_line = " | ".join(h.ljust(col_widths[i]) for i, h in enumerate(padded_headers))
        separator_line = "-+-".join("-" * col_widths[i] for i in range(num_cols))

        table_lines = [header_line, separator_line]
        for row in string_rows:
            row_line = " | ".join(cell.ljust(col_widths[i]) for i, cell in enumerate(row))
            table_lines.append(row_line)

        table_text = "\n".join(table_lines)
        return cls.pre(table_text, parse_mode=parse_mode)

    @classmethod
    def markdown_to_html(cls, md_text: str) -> str:
        """Converts standard Markdown/CommonMark to Telegram HTML format."""
        if not md_text:
            return ""

        result = md_text

        # 1. Pre blocks: ```lang\ncode\n```
        pre_blocks: List[str] = []
        def _pre_sub(m):
            lang = m.group(1) or ""
            code_body = html.escape(m.group(2).strip("\n"))
            if lang:
                tag = f'<pre><code class="language-{html.escape(lang)}">{code_body}</code></pre>'
            else:
                tag = f"<pre>{code_body}</pre>"
            pre_blocks.append(tag)
            return f"@@PRE_{len(pre_blocks) - 1}@@"

        result = re.sub(r"```([a-zA-Z0-9_]*)\n?(.*?)```", _pre_sub, result, flags=re.DOTALL)

        # 2. Inline code: `code`
        inline_codes: List[str] = []
        def _code_sub(m):
            c_text = html.escape(m.group(1))
            inline_codes.append(f"<code>{c_text}</code>")
            return f"@@CODE_{len(inline_codes) - 1}@@"

        result = re.sub(r"`([^`\n]+)`", _code_sub, result)

        # 3. Links: [text](url)
        links: List[str] = []
        def _link_sub(m):
            anchor = m.group(1)
            url = m.group(2)
            links.append(f'<a href="{html.escape(url, quote=True)}">{html.escape(anchor)}</a>')
            return f"@@LINK_{len(links) - 1}@@"

        result = re.sub(r"\[(.*?)\]\((.*?)\)", _link_sub, result)

        # 4. Bold: **text**
        result = re.sub(r"\*\*(.*?)\*\*", r"<b>\1</b>", result)

        # 5. Underline: __text__
        result = re.sub(r"__(.*?)__", r"<u>\1</u>", result)

        # 6. Italic: *text* or _text_
        result = re.sub(r"(?<!\w)\*([^\*\n]+)\*(?!\w)", r"<i>\1</i>", result)
        result = re.sub(r"(?<!\w)_([^_\n]+)_(?!\w)", r"<i>\1</i>", result)

        # 7. Strikethrough: ~~text~~ or ~text~
        result = re.sub(r"~~(.*?)~~", r"<s>\1</s>", result)
        result = re.sub(r"~([^~\n]+)~", r"<s>\1</s>", result)

        # 8. Spoilers: ||text||
        result = re.sub(r"\|\|(.*?)\|\|", r"<tg-spoiler>\1</tg-spoiler>", result)

        # 9. Blockquotes: > line
        result = re.sub(r"^>\s*(.*?)$", r"<blockquote>\1</blockquote>", result, flags=re.MULTILINE)

        # Restore isolated elements
        for idx, block in enumerate(pre_blocks):
            result = result.replace(f"@@PRE_{idx}@@", block)
        for idx, block in enumerate(inline_codes):
            result = result.replace(f"@@CODE_{idx}@@", block)
        for idx, block in enumerate(links):
            result = result.replace(f"@@LINK_{idx}@@", block)

        return result

    @classmethod
    def html_to_markdown_v2(cls, html_text: str) -> str:
        """Converts Telegram HTML markup into compliant Telegram MarkdownV2 format."""
        if not html_text:
            return ""

        result = html_text

        # 1. Pre blocks
        pre_blocks: List[str] = []
        def _extract_pre(m):
            lang = m.group(1) or ""
            code_content = m.group(2)
            raw_code = html.unescape(code_content)
            escaped = cls.escape_markdown_v2(raw_code, as_code=True)
            pre_blocks.append(f"```{lang}\n{escaped}\n```")
            return f"@@PRE_{len(pre_blocks)-1}@@"

        result = re.sub(
            r'<pre><code(?:\s+class="language-([a-zA-Z0-9_]+)")?>(.*?)</code></pre>',
            _extract_pre,
            result,
            flags=re.DOTALL | re.IGNORECASE,
        )
        result = re.sub(
            r'<pre>(.*?)</pre>',
            lambda m: _extract_pre(re.match(r'(?:<code.*?>)?(.*)', m.group(1), re.DOTALL) or m),
            result,
            flags=re.DOTALL | re.IGNORECASE,
        )

        # 2. Inline code
        inline_codes: List[str] = []
        def _extract_code(m):
            raw = html.unescape(m.group(1))
            escaped = cls.escape_markdown_v2(raw, as_code=True)
            inline_codes.append(f"`{escaped}`")
            return f"@@CODE_{len(inline_codes)-1}@@"

        result = re.sub(r'<code>(.*?)</code>', _extract_code, result, flags=re.DOTALL | re.IGNORECASE)

        # 3. Links
        links: List[str] = []
        def _extract_link(m):
            url = html.unescape(m.group(1))
            anchor_text = html.unescape(m.group(2))
            esc_text = cls.escape_markdown_v2(anchor_text)
            esc_url = cls.escape_markdown_v2(url, as_link_url=True)
            links.append(f"[{esc_text}]({esc_url})")
            return f"@@LINK_{len(links)-1}@@"

        result = re.sub(r'<a\s+href="([^"]+)"[^>]*>(.*?)</a>', _extract_link, result, flags=re.DOTALL | re.IGNORECASE)

        # 4. Formatted tokens (bold, italic, underline, strikethrough, spoiler, blockquote)
        formatted_nodes: List[str] = []
        def _extract_formatted(m, wrapper_prefix, wrapper_suffix):
            inner_text = html.unescape(m.group(1))
            esc_inner = cls.escape_markdown_v2(inner_text)
            formatted_nodes.append(f"{wrapper_prefix}{esc_inner}{wrapper_suffix}")
            return f"@@FMT_{len(formatted_nodes)-1}@@"

        result = re.sub(r'<b>(.*?)</b>', lambda m: _extract_formatted(m, "*", "*"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<strong>(.*?)</strong>', lambda m: _extract_formatted(m, "*", "*"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<i>(.*?)</i>', lambda m: _extract_formatted(m, "_", "_"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<em>(.*?)</em>', lambda m: _extract_formatted(m, "_", "_"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<u>(.*?)</u>', lambda m: _extract_formatted(m, "__", "__"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<s>(.*?)</s>', lambda m: _extract_formatted(m, "~", "~"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<strike>(.*?)</strike>', lambda m: _extract_formatted(m, "~", "~"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<tg-spoiler>(.*?)</tg-spoiler>', lambda m: _extract_formatted(m, "||", "||"), result, flags=re.DOTALL | re.IGNORECASE)
        result = re.sub(r'<blockquote(?:\s+expandable="")?>(.*?)</blockquote>', lambda m: _extract_formatted(m, ">", ""), result, flags=re.DOTALL | re.IGNORECASE)

        # 5. Escape all plain text outside placeholders
        parts = re.split(r'(@@(?:PRE|CODE|LINK|FMT)_\d+@@)', result)
        out_parts = []
        for part in parts:
            if re.match(r'^@@(?:PRE|CODE|LINK|FMT)_\d+@@$', part):
                out_parts.append(part)
            else:
                raw_text = html.unescape(part)
                out_parts.append(cls.escape_markdown_v2(raw_text))

        reconstructed = "".join(out_parts)

        # Restore formatted nodes, links, code, and pre blocks
        for i, b in enumerate(formatted_nodes):
            reconstructed = reconstructed.replace(f"@@FMT_{i}@@", b)
        for i, b in enumerate(links):
            reconstructed = reconstructed.replace(f"@@LINK_{i}@@", b)
        for i, b in enumerate(inline_codes):
            reconstructed = reconstructed.replace(f"@@CODE_{i}@@", b)
        for i, b in enumerate(pre_blocks):
            reconstructed = reconstructed.replace(f"@@PRE_{i}@@", b)

        return reconstructed

    @classmethod
    def strip_formatting(cls, text: str, parse_mode: Union[ParseMode, str] = ParseMode.MARKDOWN_V2) -> str:
        """Strips all markup tags and backslash escapes to return clean plain text."""
        if not text:
            return ""

        clean = text
        mode = ParseMode(parse_mode)

        if mode in (ParseMode.HTML, "HTML"):
            clean = re.sub(r"<[^>]+>", "", clean)
            clean = html.unescape(clean)
        elif mode in (ParseMode.MARKDOWN_V2, "MarkdownV2"):
            # Remove link syntax: [text](url) -> text (url)
            clean = re.sub(r"\[(.*?)\]\((.*?)\)", r"\1 (\2)", clean)
            # Remove markdown delimiters
            clean = re.sub(r"(\*\*|\*|__|_|~~|~|\|\||```|`|>)", "", clean)
            # Unescape backslash escapes
            clean = re.sub(r"\\([_\*\[\]\(\)~`>#\+\-=\|{}\.!])", r"\1", clean)
        elif mode in (ParseMode.MARKDOWN, "Markdown"):
            clean = re.sub(r"\[(.*?)\]\((.*?)\)", r"\1 (\2)", clean)
            clean = re.sub(r"(\*|_|```|`)", "", clean)

        return clean.strip()
