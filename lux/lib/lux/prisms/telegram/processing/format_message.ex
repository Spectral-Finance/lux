defmodule Lux.Prisms.Telegram.Processing.FormatMessage do
  @moduledoc """
  Provides formatting utilities for Telegram messages (MarkdownV2 and HTML).
  """
  use Lux.Prism,
    name: "Format Telegram Message",
    description: "Escapes strings or formats text for Telegram MarkdownV2 or HTML parsing modes",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Text to format"},
        mode: %{type: :string, enum: ["MarkdownV2", "HTML"], description: "Target parse mode"},
        escape_only: %{type: :boolean, description: "If true, only escape special characters instead of applying styles"}
      },
      required: ["text", "mode"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        formatted_text: %{type: :string}
      },
      required: ["formatted_text"]
    }

  @markdown_v2_escape_chars ["_", "*", "[", "]", "(", ")", "~", "`", ">", "#", "+", "-", "=", "|", "{", "}", ".", "!"]
  @html_escape_map %{"&" => "&amp;", "<" => "&lt;", ">" => "&gt;"}

  def handler(params, _ctx) do
    text = Map.get(params, :text) || Map.get(params, "text") || ""
    mode = Map.get(params, :mode) || Map.get(params, "mode")
    escape_only = Map.get(params, :escape_only) || Map.get(params, "escape_only") || true

    formatted = 
      case {mode, escape_only} do
        {"MarkdownV2", true} -> escape_markdown_v2(text)
        {"HTML", true} -> escape_html(text)
        _ -> text # Other formatting logic could be implemented
      end

    {:ok, %{formatted_text: formatted}}
  end

  defp escape_markdown_v2(text) do
    Enum.reduce(@markdown_v2_escape_chars, text, fn char, acc ->
      String.replace(acc, char, "\\" <> char)
    end)
  end

  defp escape_html(text) do
    Enum.reduce(@html_escape_map, text, fn {char, replacement}, acc ->
      String.replace(acc, char, replacement)
    end)
  end
end
