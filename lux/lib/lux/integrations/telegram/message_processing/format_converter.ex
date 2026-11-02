defmodule Lux.Integrations.Telegram.MessageProcessing.FormatConverter do
  @moduledoc """
  Telegram message formatting, escaping, and format conversion utilities.
  Supports HTML, Markdown (legacy), and MarkdownV2, as well as entity-to-markup
  conversion and smart message chunking for messages exceeding Telegram's 4096 limit.
  """

  @max_telegram_message_length 4096

  @markdown_v2_escapes [
    "\\",
    "_",
    "*",
    "[",
    "]",
    "(",
    ")",
    "~",
    "`",
    ">",
    "#",
    "+",
    "-",
    "=",
    "|",
    "{",
    "}",
    ".",
    "!"
  ]

  @doc """
  Escapes characters for Telegram HTML mode.
  Escapes `&`, `<`, `>`, and `"`.
  """
  @spec escape_html(String.t()) :: String.t()
  def escape_html(nil), do: ""

  def escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  @doc """
  Escapes characters for Telegram legacy Markdown mode.
  """
  @spec escape_markdown(String.t()) :: String.t()
  def escape_markdown(nil), do: ""

  def escape_markdown(text) when is_binary(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace("_", "\\_")
    |> String.replace("*", "\\*")
    |> String.replace("`", "\\`")
    |> String.replace("[", "\\[")
  end

  @doc """
  Escapes all special characters for Telegram MarkdownV2 mode:
  `_`, `*`, `[`, `]`, `(`, `)`, `~`, `` ` ``, `>`, `#`, `+`, `-`, `=`, `|`, `{`, `}`, `.`, `!`, `\\`.
  """
  @spec escape_markdown_v2(String.t()) :: String.t()
  def escape_markdown_v2(nil), do: ""

  def escape_markdown_v2(text) when is_binary(text) do
    # Escape backslash first to prevent double escaping
    escaped_slash = String.replace(text, "\\", "\\\\")

    Enum.reduce(@markdown_v2_escapes -- ["\\"], escaped_slash, fn char, acc ->
      String.replace(acc, char, "\\" <> char)
    end)
  end

  @doc """
  Converts standard Markdown text into Telegram-compliant HTML.
  Supports bold, italic, strikethrough, code blocks, inline code, links, and blockquotes.
  """
  @spec markdown_to_html(String.t()) :: String.t()
  def markdown_to_html(nil), do: ""

  def markdown_to_html(text) when is_binary(text) do
    text
    # Escape HTML entities first to avoid injection
    |> escape_html()
    # Code blocks (multiline)
    |> String.replace(~r/```([a-zA-Z0-9_-]*)\n([\s\S]*?)```/, "<pre><code class=\"language-\\1\">\\2</code></pre>")
    # Inline code
    |> String.replace(~r/`([^`]+)`/, "<code>\\1</code>")
    # Bold (** or *)
    |> String.replace(~r/\*\*([^*]+)\*\*/, "<b>\\1</b>")
    |> String.replace(~r/\*([^*]+)\*/, "<b>\\1</b>")
    # Italic (__ or _)
    |> String.replace(~r/__([^_]+)__/, "<i>\\1</i>")
    |> String.replace(~r/_([^_]+)_/, "<i>\\1</i>")
    # Strikethrough (~~)
    |> String.replace(~r/~~([^~]+)~~/, "<s>\\1</s>")
    # Spoiler (||)
    |> String.replace(~r/\|\|([^|]+)\|\|/, "<tg-spoiler>\\1</tg-spoiler>")
    # Links [label](url)
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, "<a href=\"\\2\">\\1</a>")
  end

  @doc """
  Converts Telegram HTML formatted text to MarkdownV2.
  """
  @spec html_to_markdown_v2(String.t()) :: String.t()
  def html_to_markdown_v2(nil), do: ""

  def html_to_markdown_v2(text) when is_binary(text) do
    text
    # Bold
    |> String.replace(~r/<(b|strong)>([\s\S]*?)<\/\1>/i, "*\\2*")
    # Italic
    |> String.replace(~r/<(i|em)>([\s\S]*?)<\/\1>/i, "_\\2_")
    # Underline
    |> String.replace(~r/<(u|ins)>([\s\S]*?)<\/\1>/i, "__\\2__")
    # Strikethrough
    |> String.replace(~r/<(s|strike|del)>([\s\S]*?)<\/\1>/i, "~\\2~")
    # Spoiler
    |> String.replace(~r/<tg-spoiler>([\s\S]*?)<\/tg-spoiler>/i, "||\\1||")
    # Pre / Code blocks
    |> String.replace(~r/<pre><code(?: class="[^"]*")?>([\s\S]*?)<\/code><\/pre>/i, "```\n\\1```")
    |> String.replace(~r/<pre>([\s\S]*?)<\/pre>/i, "```\n\\1```")
    |> String.replace(~r/<code>([\s\S]*?)<\/code>/i, "`\\1`")
    # Links
    |> String.replace(~r/<a\s+href="([^"]+)">([\s\S]*?)<\/a>/i, "[\\2](\\1)")
    # Blockquote
    |> String.replace(~r/<blockquote>([\s\S]*?)<\/blockquote>/i, ">\\1")
    # Unescape HTML entities
    |> String.replace("&quot;", "\"")
    |> String.replace("&gt;", ">")
    |> String.replace("&lt;", "<")
    |> String.replace("&amp;", "&")
  end

  @doc """
  Converts plain text and a list of Telegram MessageEntity maps into Telegram HTML.
  """
  @spec entities_to_html(String.t(), list(map())) :: String.t()
  def entities_to_html(text, entities) when is_binary(text) and is_list(entities) do
    # Sort entities in descending order of offset to replace from back to front
    sorted =
      entities
      |> Enum.sort_by(fn e ->
        offset = Map.get(e, :offset) || Map.get(e, "offset", 0)
        -offset
      end)

    Enum.reduce(sorted, text, fn entity, current_text ->
      offset = Map.get(entity, :offset) || Map.get(entity, "offset", 0)
      length = Map.get(entity, :length) || Map.get(entity, "length", 0)
      type = to_string(Map.get(entity, :type) || Map.get(entity, "type", ""))
      url = Map.get(entity, :url) || Map.get(entity, "url")

      target = String.slice(current_text, offset, length)
      wrapped = wrap_entity_html(target, type, url)

      prefix = String.slice(current_text, 0, offset)
      suffix = String.slice(current_text, offset + length..-1//1)
      prefix <> wrapped <> suffix
    end)
  end

  def entities_to_html(text, _), do: escape_html(text)

  defp wrap_entity_html(text, "bold", _), do: "<b>#{escape_html(text)}</b>"
  defp wrap_entity_html(text, "italic", _), do: "<i>#{escape_html(text)}</i>"
  defp wrap_entity_html(text, "underline", _), do: "<u>#{escape_html(text)}</u>"
  defp wrap_entity_html(text, "strikethrough", _), do: "<s>#{escape_html(text)}</s>"
  defp wrap_entity_html(text, "spoiler", _), do: "<tg-spoiler>#{escape_html(text)}</tg-spoiler>"
  defp wrap_entity_html(text, "code", _), do: "<code>#{escape_html(text)}</code>"
  defp wrap_entity_html(text, "pre", _), do: "<pre>#{escape_html(text)}</pre>"
  defp wrap_entity_html(text, "text_link", url), do: "<a href=\"#{url}\">#{escape_html(text)}</a>"
  defp wrap_entity_html(text, "blockquote", _), do: "<blockquote>#{escape_html(text)}</blockquote>"
  defp wrap_entity_html(text, _, _), do: escape_html(text)

  @doc """
  Splits long message into chunks <= max_length (default 4096),
  attempting to split at line breaks or word boundaries.
  """
  @spec chunk_message(String.t(), integer()) :: list(String.t())
  def chunk_message(text, max_length \\ @max_telegram_message_length)
  def chunk_message(nil, _), do: []
  def chunk_message("", _), do: [""]

  def chunk_message(text, max_length) when is_binary(text) and is_integer(max_length) do
    if String.length(text) <= max_length do
      [text]
    else
      do_chunk(text, max_length, [])
    end
  end

  defp do_chunk("", _max_length, acc), do: Enum.reverse(acc)

  defp do_chunk(remaining, max_length, acc) do
    if String.length(remaining) <= max_length do
      Enum.reverse([remaining | acc])
    else
      split_point = find_split_point(remaining, max_length)
      {chunk, rest} = String.split_at(remaining, split_point)
      do_chunk(String.trim_leading(rest), max_length, [String.trim_trailing(chunk) | acc])
    end
  end

  defp find_split_point(text, max_length) do
    candidate = String.slice(text, 0, max_length)

    # Try to find last newline
    case :binary.matches(candidate, "\n") do
      [] ->
        # Try to find last space
        case :binary.matches(candidate, " ") do
          [] -> max_length
          matches -> elem(List.last(matches), 0)
        end

      matches ->
        elem(List.last(matches), 0) + 1
    end
  end
end
