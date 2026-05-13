defmodule Lux.Prisms.Telegram.Processing.FormatMessage do
  @moduledoc """
  Converts normalized message text and Telegram entities into sendable formats.

  The prism supports plain text, Telegram Markdown/MarkdownV2, and HTML output.
  It is intentionally local and deterministic, so agents can prepare responses
  before calling Telegram send/edit prisms.
  """

  use Lux.Prism,
    name: "Format Telegram Message",
    description: "Formats text and Telegram-style entities as plain text, Markdown, MarkdownV2, or HTML",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Raw message text"},
        entities: %{type: :array, description: "Telegram-style text entities with offset, length, type, and optional url"},
        target_format: %{
          type: :string,
          description: "Output format",
          enum: ["plain", "Markdown", "MarkdownV2", "HTML"]
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Formatted text"},
        parse_mode: %{type: :string, description: "Telegram parse_mode to use when sending"},
        target_format: %{type: :string, description: "Normalized target format"}
      },
      required: ["text", "target_format"]
    }

  @doc """
  Formats text for Telegram output.
  """
  def handler(params, _agent) when is_map(params) do
    with {:ok, text} <- validate_text(params),
         {:ok, target_format} <- validate_target_format(params) do
      entities = params |> value(:entities, []) |> normalize_entities()
      formatted_text = format_text(text, entities, target_format)

      {:ok,
       %{
         text: formatted_text,
         parse_mode: parse_mode(target_format),
         target_format: target_format
       }}
    end
  end

  def handler(_params, _agent), do: {:error, "Missing or invalid text"}

  defp validate_text(params) do
    case value(params, :text) do
      text when is_binary(text) -> {:ok, text}
      _ -> {:error, "Missing or invalid text"}
    end
  end

  defp validate_target_format(params) do
    target_format = value(params, :target_format, "plain")

    if target_format in ["plain", "Markdown", "MarkdownV2", "HTML"] do
      {:ok, target_format}
    else
      {:error, "Unsupported target_format"}
    end
  end

  defp normalize_entities(entities) when is_list(entities) do
    entities
    |> Enum.map(&normalize_entity/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.offset)
  end

  defp normalize_entities(_entities), do: []

  defp normalize_entity(entity) when is_map(entity) do
    offset = value(entity, :offset)
    length = value(entity, :length)
    type = value(entity, :type)

    if is_integer(offset) and is_integer(length) and is_binary(type) and length > 0 do
      %{offset: offset, length: length, type: type, url: value(entity, :url)}
    end
  end

  defp normalize_entity(_entity), do: nil

  defp format_text(text, [], "plain"), do: text
  defp format_text(text, [], "HTML"), do: escape_html(text)
  defp format_text(text, [], "Markdown"), do: text
  defp format_text(text, [], "MarkdownV2"), do: escape_markdown_v2(text)

  defp format_text(text, entities, target_format) do
    graphemes = String.graphemes(text)

    {chunks, cursor} =
      Enum.reduce(entities, {[], 0}, fn entity, {chunks, cursor} ->
        cond do
          entity.offset < cursor ->
            {chunks, cursor}

          entity.offset >= length(graphemes) ->
            {chunks, cursor}

          true ->
            before_entity = slice_join(graphemes, cursor, entity.offset - cursor)
            entity_text = slice_join(graphemes, entity.offset, entity.length)
            next_cursor = entity.offset + entity.length

            next_chunks =
              chunks ++
                [
                  escape_text(before_entity, target_format),
                  wrap_entity(entity, entity_text, target_format)
                ]

            {next_chunks, next_cursor}
        end
      end)

    tail = slice_join(graphemes, cursor, length(graphemes) - cursor)
    Enum.join(chunks ++ [escape_text(tail, target_format)])
  end

  defp wrap_entity(%{type: "bold"}, text, "HTML"), do: "<b>#{escape_html(text)}</b>"
  defp wrap_entity(%{type: "italic"}, text, "HTML"), do: "<i>#{escape_html(text)}</i>"
  defp wrap_entity(%{type: "code"}, text, "HTML"), do: "<code>#{escape_html(text)}</code>"
  defp wrap_entity(%{type: "pre"}, text, "HTML"), do: "<pre>#{escape_html(text)}</pre>"

  defp wrap_entity(%{type: "text_link", url: url}, text, "HTML") when is_binary(url) do
    ~s(<a href="#{escape_html(url)}">#{escape_html(text)}</a>)
  end

  defp wrap_entity(%{type: "bold"}, text, "Markdown"), do: "*#{text}*"
  defp wrap_entity(%{type: "italic"}, text, "Markdown"), do: "_#{text}_"
  defp wrap_entity(%{type: "code"}, text, "Markdown"), do: "`#{text}`"
  defp wrap_entity(%{type: "pre"}, text, "Markdown"), do: "```\n#{text}\n```"

  defp wrap_entity(%{type: "bold"}, text, "MarkdownV2"), do: "*#{escape_markdown_v2(text)}*"
  defp wrap_entity(%{type: "italic"}, text, "MarkdownV2"), do: "_#{escape_markdown_v2(text)}_"
  defp wrap_entity(%{type: "code"}, text, "MarkdownV2"), do: "`#{String.replace(text, "`", "\\`")}`"
  defp wrap_entity(%{type: "pre"}, text, "MarkdownV2"), do: "```\n#{String.replace(text, "`", "\\`")}\n```"

  defp wrap_entity(_entity, text, target_format), do: escape_text(text, target_format)

  defp escape_text(text, "HTML"), do: escape_html(text)
  defp escape_text(text, "MarkdownV2"), do: escape_markdown_v2(text)
  defp escape_text(text, _target_format), do: text

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_markdown_v2(text) do
    Regex.replace(~r/[_*\[\]()~`>#+\-=|{}.!]/, text, fn match -> "\\" <> match end)
  end

  defp parse_mode("plain"), do: nil
  defp parse_mode(target_format), do: target_format

  defp slice_join(_graphemes, _offset, length) when length <= 0, do: ""
  defp slice_join(graphemes, offset, length), do: graphemes |> Enum.slice(offset, length) |> Enum.join()

  defp value(map, key, default) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key)) || default
  end

  defp value(map, key), do: value(map, key, nil)
end
