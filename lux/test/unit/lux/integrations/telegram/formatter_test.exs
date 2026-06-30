defmodule Lux.Integrations.Telegram.FormatterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Formatter

  describe "escape_markdown/1" do
    test "escapes MarkdownV2 special characters" do
      assert Formatter.escape_markdown("Hello! Welcome to +Lux-framework.") ==
               "Hello\\! Welcome to \\+Lux\\-framework\\."
    end
  end

  describe "escape_html/1" do
    test "escapes HTML entities" do
      assert Formatter.escape_html("<hello & welcome>") == "&lt;hello &amp; welcome&gt;"
    end
  end

  describe "formatting helpers" do
    test "formats bold correctly" do
      assert Formatter.bold("text", :html) == "<b>text</b>"
      assert Formatter.bold("text", :markdown) == "*text*"
    end

    test "formats italic correctly" do
      assert Formatter.italic("text", :html) == "<i>text</i>"
      assert Formatter.italic("text", :markdown) == "_text_"
    end

    test "formats code blocks" do
      assert Formatter.code("x = 1", :html) == "<code>x = 1</code>"
      assert Formatter.code("x = 1", :markdown) == "`x \\= 1`"
    end

    test "formats links" do
      assert Formatter.link("Lux", "https://lux.io", :html) ==
               "<a href=\"https://lux.io\">Lux</a>"
               
      assert Formatter.link("Lux Framework", "https://lux.io/path?query=1)2", :markdown) ==
               "[Lux Framework](https://lux.io/path?query=1\\)2)"
    end
  end
end
