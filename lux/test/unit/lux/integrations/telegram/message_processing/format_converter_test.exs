defmodule Lux.Integrations.Telegram.MessageProcessing.FormatConverterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.FormatConverter

  describe "escaping utilities" do
    test "escape_html/1 escapes &, <, >, and \"" do
      raw = ~s(<script>alert("test" & 'hello');</script>)
      escaped = FormatConverter.escape_html(raw)

      assert escaped ==
               "&lt;script&gt;alert(&quot;test&quot; &amp; 'hello');&lt;/script&gt;"
    end

    test "escape_markdown/1 escapes special characters" do
      raw = "*bold* _italic_ `code` [link]"
      escaped = FormatConverter.escape_markdown(raw)
      assert escaped == "\\*bold\\* \\_italic\\_ \\`code\\` \\[link]"
    end

    test "escape_markdown_v2/1 escapes all 18 MarkdownV2 characters" do
      raw = "Price: $100.00! [ETH-USDC] #crypto (1+1=2) ~strike~ | spoiler"
      escaped = FormatConverter.escape_markdown_v2(raw)
      assert String.contains?(escaped, "\\.")
      assert String.contains?(escaped, "\\!")
      assert String.contains?(escaped, "\\[")
      assert String.contains?(escaped, "\\]")
      assert String.contains?(escaped, "\\(")
      assert String.contains?(escaped, "\\)")
      assert String.contains?(escaped, "\\-")
      assert String.contains?(escaped, "\\=")
      assert String.contains?(escaped, "\\#")
      assert String.contains?(escaped, "\\~")
      assert String.contains?(escaped, "\\|")
    end
  end

  describe "markdown_to_html/1" do
    test "converts markdown formatting into Telegram HTML" do
      markdown = """
      *Bold title* and _italic description_
      `code sample`
      [Official Website](https://spectral.finance)
      ||hidden secret||
      ~~deprecated option~~
      """

      html = FormatConverter.markdown_to_html(markdown)
      assert String.contains?(html, "<b>Bold title</b>")
      assert String.contains?(html, "<i>italic description</i>")
      assert String.contains?(html, "<code>code sample</code>")
      assert String.contains?(html, "<a href=\"https://spectral.finance\">Official Website</a>")
      assert String.contains?(html, "<tg-spoiler>hidden secret</tg-spoiler>")
      assert String.contains?(html, "<s>deprecated option</s>")
    end
  end

  describe "html_to_markdown_v2/1" do
    test "converts HTML to MarkdownV2" do
      html = "<b>Strong</b> and <i>emphasized</i> with <tg-spoiler>spoiler</tg-spoiler>"
      v2 = FormatConverter.html_to_markdown_v2(html)
      assert v2 == "*Strong* and _emphasized_ with ||spoiler||"
    end
  end

  describe "entities_to_html/2" do
    test "accurately reconstructs HTML from entity offsets" do
      text = "Join our Discord and check docs today!"
      entities = [
        %{type: "bold", offset: 9, length: 7},
        %{type: "text_link", offset: 27, length: 4, url: "https://docs.lux.xyz"}
      ]

      result = FormatConverter.entities_to_html(text, entities)
      assert String.contains?(result, "<b>Discord</b>")
      assert String.contains?(result, "<a href=\"https://docs.lux.xyz\">docs</a>")
    end
  end

  describe "chunk_message/2" do
    test "keeps message intact if under 4096 chars" do
      short = "Short message"
      assert FormatConverter.chunk_message(short) == [short]
    end

    test "chunks long text cleanly at newlines or spaces" do
      long_text = String.duplicate("Line of text.\n", 500)
      chunks = FormatConverter.chunk_message(long_text, 1000)

      assert length(chunks) > 1
      assert Enum.all?(chunks, fn c -> String.length(c) <= 1000 end)
    end
  end
end
