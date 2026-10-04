"""
Unit tests for TelegramFormatter (MarkdownV2, HTML, Plain text conversions & escaping).
"""

import pytest
from lux.telegram.formatter import TelegramFormatter
from lux.telegram.types import ParseMode


def test_escape_markdown_v2_all_special_chars():
    special_text = "_*[]()~`>#+-=|{}.!"
    escaped = TelegramFormatter.escape_markdown_v2(special_text)
    # Every char must be preceded by backslash
    for ch in special_text:
        assert f"\\{ch}" in escaped


def test_escape_markdown_v2_code_and_url():
    url = "https://example.com/path(1)\\2"
    escaped_url = TelegramFormatter.escape_markdown_v2(url, as_link_url=True)
    assert "\\)" in escaped_url
    assert "\\\\" in escaped_url

    code_str = "x = `hello` \\ test"
    escaped_code = TelegramFormatter.escape_markdown_v2(code_str, as_code=True)
    assert "\\`" in escaped_code
    assert "\\\\" in escaped_code


def test_escape_html():
    raw = '<div class="test">Hello & Welcome</div>'
    escaped = TelegramFormatter.escape_html(raw)
    assert "&lt;div" in escaped
    assert "&amp;" in escaped
    assert "&quot;test&quot;" in escaped


def test_formatting_helpers_markdown_v2():
    assert TelegramFormatter.bold("hello") == "*hello*"
    assert TelegramFormatter.italic("world") == "_world_"
    assert TelegramFormatter.underline("text") == "__text__"
    assert TelegramFormatter.strikethrough("strike") == "~strike~"
    assert TelegramFormatter.spoiler("secret") == "||secret||"
    assert TelegramFormatter.code("x = 1") == "`x = 1`"
    assert "```python\nprint(1)\n```" in TelegramFormatter.pre("print(1)", language="python")
    assert TelegramFormatter.link("Google", "https://google.com") == "[Google](https://google.com)"


def test_formatting_helpers_html():
    mode = ParseMode.HTML
    assert TelegramFormatter.bold("hello", parse_mode=mode) == "<b>hello</b>"
    assert TelegramFormatter.italic("world", parse_mode=mode) == "<i>world</i>"
    assert TelegramFormatter.underline("text", parse_mode=mode) == "<u>text</u>"
    assert TelegramFormatter.strikethrough("strike", parse_mode=mode) == "<s>strike</s>"
    assert TelegramFormatter.spoiler("secret", parse_mode=mode) == "<tg-spoiler>secret</tg-spoiler>"
    assert TelegramFormatter.code("x = 1", parse_mode=mode) == "<code>x = 1</code>"
    assert '<pre><code class="language-python">print(1)</code></pre>' in TelegramFormatter.pre("print(1)", language="python", parse_mode=mode)
    assert TelegramFormatter.link("Google", "https://google.com", parse_mode=mode) == '<a href="https://google.com">Google</a>'


def test_format_table():
    headers = ["Token", "Price", "24h"]
    rows = [
        ["ETH", "$3,500", "+5.2%"],
        ["BTC", "$68,000", "-1.4%"],
    ]
    table_v2 = TelegramFormatter.format_table(headers, rows, parse_mode=ParseMode.MARKDOWN_V2)
    assert "Token" in table_v2
    assert "ETH" in table_v2
    assert "```" in table_v2


def test_markdown_to_html_conversion():
    md = "**Bold Title** with *italic* and `inline code` and [Link](https://example.com)\n```python\na = 1\n```"
    converted = TelegramFormatter.markdown_to_html(md)
    assert "<b>Bold Title</b>" in converted
    assert "<i>italic</i>" in converted
    assert "<code>inline code</code>" in converted
    assert '<a href="https://example.com">Link</a>' in converted
    assert '<pre><code class="language-python">a = 1</code></pre>' in converted


def test_html_to_markdown_v2_conversion():
    html_input = '<b>Bold</b> and <i>italic</i> with <a href="https://example.com">link</a>'
    converted = TelegramFormatter.html_to_markdown_v2(html_input)
    assert "*Bold*" in converted
    assert "_italic_" in converted
    assert "[link](https://example.com)" in converted


def test_strip_formatting():
    md_text = "*Bold* and [Link](https://google.com) and `code`"
    clean_md = TelegramFormatter.strip_formatting(md_text, parse_mode=ParseMode.MARKDOWN_V2)
    assert clean_md == "Bold and Link (https://google.com) and code"

    html_text = "<b>Bold</b> and <a href='https://google.com'>Link</a>"
    clean_html = TelegramFormatter.strip_formatting(html_text, parse_mode=ParseMode.HTML)
    assert clean_html == "Bold and Link"
