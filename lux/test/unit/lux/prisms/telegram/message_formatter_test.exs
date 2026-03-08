defmodule Lux.Prisms.Telegram.MessageFormatterTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.MessageFormatter

  test "bold in HTML" do
    assert MessageFormatter.bold("hello", :html) == "<b>hello</b>"
  end

  test "bold in MarkdownV2" do
    assert MessageFormatter.bold("hello", :markdownv2) == "*hello*"
  end

  test "italic in HTML" do
    assert MessageFormatter.italic("text", :html) == "<i>text</i>"
  end

  test "code in HTML" do
    assert MessageFormatter.code("x = 1", :html) == "<code>x = 1</code>"
  end

  test "spoiler in HTML" do
    assert MessageFormatter.spoiler("secret", :html) == "<tg-spoiler>secret</tg-spoiler>"
  end

  test "spoiler in MarkdownV2" do
    assert MessageFormatter.spoiler("secret", :markdownv2) == "||secret||"
  end

  test "link in HTML" do
    assert MessageFormatter.link("click", "https://example.com", :html) ==
      "<a href=\"https://example.com\">click</a>"
  end

  test "link in MarkdownV2" do
    assert MessageFormatter.link("click", "https://example.com", :markdownv2) ==
      "[click](https://example.com)"
  end

  test "escape HTML special chars" do
    assert MessageFormatter.escape_html("<b>test & \"quote\"</b>") ==
      "&lt;b&gt;test &amp; &quot;quote&quot;&lt;/b&gt;"
  end

  test "escape MarkdownV2 special chars" do
    escaped = MessageFormatter.escape_mdv2("hello_world*test")
    assert String.contains?(escaped, "\\_")
    assert String.contains?(escaped, "\\*")
  end

  test "strip formatting" do
    assert MessageFormatter.strip_formatting("<b>bold</b> *md* `code`") ==
      "bold md code"
  end

  test "pre with language in HTML" do
    result = MessageFormatter.pre("code", :html, "elixir")
    assert result == "<pre><code class=\"language-elixir\">code</code></pre>"
  end

  test "handler formats text" do
    {:ok, result} = MessageFormatter.handler(%{text: "hello <world>", target_format: "html"}, nil)
    assert result.formatted == "hello &lt;world&gt;"
  end
end
