defmodule Lux.Prisms.Telegram.Messages.FormatText do
  @moduledoc """
  A prism for converting message text between Telegram's supported formats.

  Converts between Markdown, MarkdownV2, and HTML formatting modes,
  enabling consistent message formatting across different parse modes.

  ## Implementation Details

  - Converts Markdown (`*bold*`, `_italic_`, `` `code` ``) to HTML and MarkdownV2
  - Converts HTML (`<b>`, `<i>`, `<code>`) to Markdown and MarkdownV2
  - Escapes special characters required by each format
  - Pure computation — no API call required

  ## Examples

      iex> FormatText.handler(%{text: "*bold* and _italic_", from: "Markdown", to: "HTML"}, %{})
      {:ok, %{formatted: "<b>bold</b> and <i>italic</i>", parse_mode: "HTML"}}

      iex> FormatText.handler(%{text: "<b>Hello</b> <i>World</i>", from: "HTML", to: "Markdown"}, %{})
      {:ok, %{formatted: "*Hello* _World_", parse_mode: "Markdown"}}

      iex> FormatText.handler(%{text: "Plain text", from: "Markdown", to: "MarkdownV2"}, %{})
      {:ok, %{formatted: "Plain text", parse_mode: "MarkdownV2"}}
  """

  use Lux.Prism,
    name: "Format Telegram Message Text",
    description: "Converts message text between Telegram parse modes: Markdown, MarkdownV2, and HTML",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text to format"
        },
        from: %{
          type: :string,
          description: "Source format",
          enum: ["Markdown", "MarkdownV2", "HTML", "plain"]
        },
        to: %{
          type: :string,
          description: "Target format",
          enum: ["Markdown", "MarkdownV2", "HTML", "plain"]
        }
      },
      required: ["text", "from", "to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        formatted: %{type: :string, description: "The formatted text in the target format"},
        parse_mode: %{type: :string, description: "The Telegram parse_mode to use with this text"}
      }
    }

  @impl true
  def handler(%{text: text, from: from, to: to}, _agent) do
    formatted = convert(to_string(text), to_string(from), to_string(to))
    {:ok, %{formatted: formatted, parse_mode: parse_mode_for(to)}}
  end

  def handler(%{"text" => text, "from" => from, "to" => to} = params, agent) do
    handler(%{text: text, from: from, to: to} |> Map.merge(stringify_keys_to_atoms(params)), agent)
  end

  # Same format — no conversion needed
  defp convert(text, same, same), do: text

  # Markdown → HTML
  defp convert(text, "Markdown", "HTML") do
    text
    |> replace_code_spans("HTML")
    |> String.replace(~r/\*([^*]+)\*/, "<b>\\1</b>")
    |> String.replace(~r/_([^_]+)_/, "<i>\\1</i>")
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, "<a href=\"\\2\">\\1</a>")
  end

  # HTML → Markdown
  defp convert(text, "HTML", "Markdown") do
    text
    |> String.replace(~r/<b>(.+?)<\/b>/s, "*\\1*")
    |> String.replace(~r/<strong>(.+?)<\/strong>/s, "*\\1*")
    |> String.replace(~r/<i>(.+?)<\/i>/s, "_\\1_")
    |> String.replace(~r/<em>(.+?)<\/em>/s, "_\\1_")
    |> String.replace(~r/<code>(.+?)<\/code>/s, "`\\1`")
    |> String.replace(~r/<pre>(.+?)<\/pre>/s, "```\\1```")
    |> String.replace(~r/<a href="([^"]+)">(.+?)<\/a>/s, "[\\2](\\1)")
    |> strip_remaining_tags()
  end

  # Markdown → MarkdownV2
  defp convert(text, "Markdown", "MarkdownV2") do
    # First convert to HTML, then to MarkdownV2
    text
    |> convert("Markdown", "HTML")
    |> convert("HTML", "MarkdownV2")
  end

  # MarkdownV2 → HTML
  defp convert(text, "MarkdownV2", "HTML") do
    text
    |> replace_code_spans("HTML")
    |> String.replace(~r/\*([^*]+)\*/, "<b>\\1</b>")
    |> String.replace(~r/_([^_]+)_/, "<i>\\1</i>")
    |> String.replace(~r/\|\|([^|]+)\|\|/, "<tg-spoiler>\\1</tg-spoiler>")
    |> String.replace(~r/~([^~]+)~/, "<s>\\1</s>")
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, "<a href=\"\\2\">\\1</a>")
    |> unescape_mdv2()
  end

  # HTML → MarkdownV2
  defp convert(text, "HTML", "MarkdownV2") do
    text
    |> String.replace(~r/<b>(.+?)<\/b>/s, "*\\1*")
    |> String.replace(~r/<strong>(.+?)<\/strong>/s, "*\\1*")
    |> String.replace(~r/<i>(.+?)<\/i>/s, "_\\1_")
    |> String.replace(~r/<em>(.+?)<\/em>/s, "_\\1_")
    |> String.replace(~r/<s>(.+?)<\/s>/s, "~\\1~")
    |> String.replace(~r/<tg-spoiler>(.+?)<\/tg-spoiler>/s, "||\\1||")
    |> String.replace(~r/<code>(.+?)<\/code>/s, "`\\1`")
    |> String.replace(~r/<pre>(.+?)<\/pre>/s, "```\\1```")
    |> String.replace(~r/<a href="([^"]+)">(.+?)<\/a>/s, "[\\2](\\1)")
    |> strip_remaining_tags()
    |> escape_mdv2_special_chars()
  end

  # plain → any: just return text
  defp convert(text, "plain", _to), do: text
  defp convert(text, _from, "plain"), do: text

  defp parse_mode_for("Markdown"), do: "Markdown"
  defp parse_mode_for("MarkdownV2"), do: "MarkdownV2"
  defp parse_mode_for("HTML"), do: "HTML"
  defp parse_mode_for("plain"), do: "HTML"
  defp parse_mode_for(_), do: "HTML"

  defp replace_code_spans(text, "HTML") do
    text
    |> String.replace(~r/```([^`]+)```/s, "<pre>\\1</pre>")
    |> String.replace(~r/`([^`]+)`/, "<code>\\1</code>")
  end

  defp strip_remaining_tags(text) do
    Regex.replace(~r/<[^>]+>/, text, "")
  end

  defp escape_mdv2_special_chars(text) do
    # MarkdownV2 requires escaping: _ * [ ] ( ) ~ ` > # + - = | { } . !
    Regex.replace(~r/(?<!\\)([\[\]()~>#+=|{}.!-])/, text, "\\\\\\1")
  end

  defp unescape_mdv2(text) do
    String.replace(text, ~r/\\(.)/, "\\1")
  end

  defp stringify_keys_to_atoms(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          ArgumentError -> {k, v}
        end
      {k, v} -> {k, v}
    end)
  end
end
