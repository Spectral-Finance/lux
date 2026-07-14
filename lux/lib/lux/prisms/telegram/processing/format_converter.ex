defmodule Lux.Prisms.Telegram.Processing.FormatConverter do
  @moduledoc """
  A prism for formatting Telegram message entities into Markdown, MarkdownV2 or HTML.
  Handles proper HTML/Markdown escaping and correctly processes overlapping and nested entities.
  """

  use Lux.Prism,
    name: "Telegram Format Converter",
    description: "Converts Telegram message text and entities into Markdown, MarkdownV2 or HTML",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string},
        entities: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              type: %{type: :string},
              offset: %{type: :integer},
              length: %{type: :integer},
              url: %{type: :string}
            }
          }
        },
        format: %{
          type: :string,
          enum: ["markdown", "markdownv2", "html"],
          description: "Target format"
        }
      },
      required: ["text", "format"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        formatted_text: %{type: :string}
      },
      required: ["formatted_text"]
    }

  def handler(%{text: text, format: format} = params, _agent) when is_binary(text) do
    entities = Map.get(params, :entities, []) || Map.get(params, "entities", [])
    
    formatted_text = 
      case format do
        "markdown" -> apply_entities(text, entities, "markdown")
        "markdownv2" -> apply_entities(text, entities, "markdownv2")
        "html" -> apply_entities(text, entities, "html")
        _ -> text
      end
      
    {:ok, %{formatted_text: formatted_text}}
  end
  
  def handler(_params, _agent) do
    {:error, "Missing required parameters text or format"}
  end

  defp apply_entities(text, [], format) do
    escape_text(text, format)
  end

  defp apply_entities(text, entities, format) do
    utf16_list = :unicode.characters_to_list(text, :utf16)
    text_len = length(utf16_list)
    
    valid_entities = 
      entities
      |> Enum.map(fn e ->
        offset = Map.get(e, :offset) || Map.get(e, "offset") || 0
        len = Map.get(e, :length) || Map.get(e, "length") || 0
        type = Map.get(e, :type) || Map.get(e, "type")
        url = Map.get(e, :url) || Map.get(e, "url")
        %{offset: offset, length: len, type: type, url: url}
      end)
      |> Enum.filter(fn e -> e.offset >= 0 and e.length > 0 and e.offset < text_len end)
      |> Enum.map(fn e ->
        if e.offset + e.length > text_len do
          %{e | length: text_len - e.offset}
        else
          e
        end
      end)
      
    boundaries = 
      valid_entities
      |> Enum.flat_map(fn e -> [e.offset, e.offset + e.length] end)
      |> Enum.concat([0, text_len])
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.filter(fn b -> b <= text_len end)
      
    chunks = 
      boundaries
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [start_idx, end_idx] ->
        chunk_utf16 = Enum.slice(utf16_list, start_idx, end_idx - start_idx)
        chunk_str = :unicode.characters_to_binary(chunk_utf16, :utf16, :utf8)
        
        active_entities = 
          valid_entities
          |> Enum.filter(fn e -> e.offset <= start_idx and e.offset + e.length >= end_idx end)
          |> Enum.sort_by(fn e -> {-e.length, e.offset} end)
          
        {chunk_str, active_entities}
      end)
      
    merged_chunks = merge_chunks(chunks, [])
    
    formatted_chunks = 
      Enum.map(merged_chunks, fn {chunk_str, active_entities} ->
        escaped_str = escape_text(chunk_str, format)
        
        Enum.reduce(Enum.reverse(active_entities), escaped_str, fn e, acc ->
          wrap_entity(acc, e, format)
        end)
      end)
      
    Enum.join(formatted_chunks, "")
  end
  
  defp merge_chunks([], acc), do: Enum.reverse(acc)
  defp merge_chunks([current | rest], []) do
    merge_chunks(rest, [current])
  end
  defp merge_chunks([{str2, entities2} | rest], [{str1, entities1} | acc_rest]) do
    if entities1 == entities2 do
      merge_chunks(rest, [{str1 <> str2, entities1} | acc_rest])
    else
      merge_chunks(rest, [{str2, entities2}, {str1, entities1} | acc_rest])
    end
  end

  defp escape_text(text, "html") do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp escape_text(text, format) when format in ["markdown", "markdownv2"] do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace("_", "\\_")
    |> String.replace("*", "\\*")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace("~", "\\~")
    |> String.replace("`", "\\`")
    |> String.replace(">", "\\>")
    |> String.replace("#", "\\#")
    |> String.replace("+", "\\+")
    |> String.replace("-", "\\-")
    |> String.replace("=", "\\=")
    |> String.replace("|", "\\|")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace(".", "\\.")
    |> String.replace("!", "\\!")
  end

  defp wrap_entity(content, entity, "html") do
    case entity.type do
      "bold" -> "<b>#{content}</b>"
      "italic" -> "<i>#{content}</i>"
      "code" -> "<code>#{content}</code>"
      "pre" -> "<pre>#{content}</pre>"
      "text_link" -> "<a href=\"#{entity.url}\">#{content}</a>"
      "strikethrough" -> "<s>#{content}</s>"
      "underline" -> "<u>#{content}</u>"
      _ -> content
    end
  end

  defp wrap_entity(content, entity, "markdown") do
    case entity.type do
      "bold" -> "**#{content}**"
      "italic" -> "_#{content}_"
      "code" -> "`#{content}`"
      "pre" -> "```\n#{content}\n```"
      "text_link" -> "[#{content}](#{entity.url})"
      "strikethrough" -> "~~#{content}~~"
      _ -> content
    end
  end

  defp wrap_entity(content, entity, "markdownv2") do
    case entity.type do
      "bold" -> "*#{content}*"
      "italic" -> "_#{content}_"
      "code" -> "`#{content}`"
      "pre" -> "```\n#{content}\n```"
      "text_link" -> "[#{content}](#{entity.url})"
      "strikethrough" -> "~#{content}~"
      "underline" -> "__#{content}__"
      _ -> content
    end
  end
end
