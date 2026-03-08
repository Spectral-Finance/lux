defmodule Lux.Prisms.Telegram.MessageFormatter do
  @moduledoc """
  Format and convert Telegram message content between Markdown, HTML, and MarkdownV2.

  Supports:
  - Bold, italic, underline, strikethrough, code, pre, spoiler
  - Links, mentions, custom emoji
  - Entity-based formatting from parse results
  - Escaping for MarkdownV2
  """

  use Lux.Prism,
    name: "Telegram Message Formatter",
    description: "Convert message formatting between Markdown, MarkdownV2, HTML, and plain text",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string},
        format: %{type: :string, enum: ["markdown", "markdownv2", "html", "plain"]},
        target_format: %{type: :string, enum: ["markdown", "markdownv2", "html", "plain"]}
      },
      required: ["text", "target_format"]
    },
    output_schema: %{
      type: :object,
      properties: %{formatted: %{type: :string}}
    }

  @impl true
  def handler(params, _agent) do
    text = params["text"] || params[:text] || ""
    target = params["target_format"] || params[:target_format] || "html"

    {:ok, %{formatted: format(text, String.to_atom(target))}}
  end

  @doc "Build formatted text with inline styles."
  def bold(text, :html), do: "<b>#{escape_html(text)}</b>"
  def bold(text, :markdownv2), do: "*#{escape_mdv2(text)}*"
  def bold(text, _), do: "*#{text}*"

  def italic(text, :html), do: "<i>#{escape_html(text)}</i>"
  def italic(text, :markdownv2), do: "_#{escape_mdv2(text)}_"
  def italic(text, _), do: "_#{text}_"

  def underline(text, :html), do: "<u>#{escape_html(text)}</u>"
  def underline(text, :markdownv2), do: "__#{escape_mdv2(text)}__"
  def underline(text, _), do: text

  def strikethrough(text, :html), do: "<s>#{escape_html(text)}</s>"
  def strikethrough(text, :markdownv2), do: "~#{escape_mdv2(text)}~"
  def strikethrough(text, _), do: "~#{text}~"

  def code(text, :html), do: "<code>#{escape_html(text)}</code>"
  def code(text, :markdownv2), do: "`#{text}`"
  def code(text, _), do: "`#{text}`"

  def pre(text, :html, lang \\ nil) do
    if lang, do: "<pre><code class=\"language-#{lang}\">#{escape_html(text)}</code></pre>",
    else: "<pre>#{escape_html(text)}</pre>"
  end
  def pre(text, :markdownv2, lang) do
    if lang, do: "```#{lang}\n#{text}\n```", else: "```\n#{text}\n```"
  end
  def pre(text, _, lang) do
    if lang, do: "```#{lang}\n#{text}\n```", else: "```\n#{text}\n```"
  end

  def spoiler(text, :html), do: "<tg-spoiler>#{escape_html(text)}</tg-spoiler>"
  def spoiler(text, :markdownv2), do: "||#{escape_mdv2(text)}||"
  def spoiler(text, _), do: text

  def link(text, url, :html), do: "<a href=\"#{url}\">#{escape_html(text)}</a>"
  def link(text, url, :markdownv2), do: "[#{escape_mdv2(text)}](#{url})"
  def link(text, url, _), do: "[#{text}](#{url})"

  def mention(username, :html), do: "<a href=\"tg://user?id=#{username}\">@#{username}</a>"
  def mention(username, _), do: "@#{username}"

  @doc "Format plain text for a target parse mode (escaping)."
  def format(text, :html), do: escape_html(text)
  def format(text, :markdownv2), do: escape_mdv2(text)
  def format(text, :plain), do: strip_formatting(text)
  def format(text, _), do: text

  @doc "Escape text for HTML parse mode."
  def escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  @doc "Escape text for MarkdownV2 parse mode."
  def escape_mdv2(text) do
    # All special chars that need escaping in MarkdownV2
    special = ["_", "*", "[", "]", "(", ")", "~", "`", ">", "#", "+", "-", "=", "|", "{", "}", ".", "!"]
    Enum.reduce(special, text, fn char, acc ->
      String.replace(acc, char, "\\#{char}")
    end)
  end

  @doc "Strip all formatting tags to plain text."
  def strip_formatting(text) do
    text
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\*([^*]+)\*/, "\\1")
    |> String.replace(~r/_([^_]+)_/, "\\1")
    |> String.replace(~r/~([^~]+)~/, "\\1")
    |> String.replace(~r/`([^`]+)`/, "\\1")
    |> String.replace(~r/\|\|([^|]+)\|\|/, "\\1")
  end
end
