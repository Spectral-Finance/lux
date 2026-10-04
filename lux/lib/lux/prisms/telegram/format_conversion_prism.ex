defmodule Lux.Prisms.Telegram.FormatConversionPrism do
  @moduledoc """
  Prism for bidirectional formatting conversions (MarkdownV2, Telegram HTML, Plain text).
  """

  use Lux.Prism,
    name: "Telegram Format Conversion Prism",
    description: "Converts text between MarkdownV2, Telegram HTML, and Plain text with strict escaping.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Input text to format or convert"},
        source_format: %{type: :string, enum: ["markdown", "html", "markdown_v2", "plain"]},
        target_format: %{type: :string, enum: ["markdown_v2", "html", "plain"]}
      },
      required: ["text", "target_format"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        formatted_text: %{type: :string},
        target_format: %{type: :string}
      }
    }

  @impl true
  def handler(params, _agent) do
    text = params[:text] || params["text"] || ""
    source_format = params[:source_format] || params["source_format"] || "markdown"
    target_format = params[:target_format] || params["target_format"] || "markdown_v2"

    result =
      python variables: %{text: text, source_format: source_format, target_format: target_format} do
        ~PY"""
        from lux.telegram.formatter import TelegramFormatter

        out_text = text
        src = str(source_format).lower()
        tgt = str(target_format).lower()

        if tgt == "html":
            if src in ("markdown", "plain", "md"):
                out_text = TelegramFormatter.markdown_to_html(text)
            elif src in ("markdown_v2", "mdv2"):
                # First strip or convert to plain then to html
                plain = TelegramFormatter.strip_formatting(text, parse_mode="MarkdownV2")
                out_text = TelegramFormatter.markdown_to_html(plain)
        elif tgt in ("markdown_v2", "mdv2"):
            if src == "html":
                out_text = TelegramFormatter.html_to_markdown_v2(text)
            elif src in ("markdown", "plain", "md"):
                # Convert md to html first then to compliant mdv2
                html_inter = TelegramFormatter.markdown_to_html(text)
                out_text = TelegramFormatter.html_to_markdown_v2(html_inter)
        elif tgt == "plain":
            parse_mode = "HTML" if src == "html" else "MarkdownV2"
            out_text = TelegramFormatter.strip_formatting(text, parse_mode=parse_mode)

        {
            "formatted_text": out_text,
            "target_format": tgt
        }
        """
      end

    {:ok, result}
  rescue
    e in RuntimeError ->
      {:error, "Format conversion failed: #{Exception.message(e)}"}
  end
end
