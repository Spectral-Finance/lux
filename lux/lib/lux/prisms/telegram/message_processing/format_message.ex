defmodule Lux.Prisms.Telegram.MessageProcessing.FormatMessage do
  @moduledoc """
  A prism for formatting, escaping, and converting Telegram messages
  between HTML, Markdown, and MarkdownV2, including message chunking.
  """

  use Lux.Prism,
    name: "Format Telegram Message",
    description: "Transforms text into Telegram-compliant HTML or MarkdownV2 and chunks long messages",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Raw text or markup"},
        format: %{type: :string, description: "Target format: 'html', 'markdown_v2', or 'markdown'"},
        source_format: %{type: :string, description: "Source format if converting: 'markdown' or 'entities'"},
        entities: %{type: :array, description: "Optional entities list when source is 'entities'"},
        max_chunk_length: %{type: :integer, description: "Maximum chunk size (default 4096)"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        formatted_text: %{type: :string},
        parse_mode: %{type: :string},
        chunks: %{type: :array},
        chunk_count: %{type: :integer}
      },
      required: ["formatted_text", "chunks", "chunk_count"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.FormatConverter

  def handler(params, _agent) when is_map(params) do
    text = Map.get(params, :text) || Map.get(params, "text") || ""
    format = Map.get(params, :format) || Map.get(params, "format", "html")
    source_format = Map.get(params, :source_format) || Map.get(params, "source_format", "markdown")
    entities = Map.get(params, :entities) || Map.get(params, "entities", [])
    max_chunk = Map.get(params, :max_chunk_length) || Map.get(params, "max_chunk_length", 4096)

    {formatted, parse_mode} =
      case {to_string(source_format), to_string(format)} do
        {"entities", "html"} ->
          {FormatConverter.entities_to_html(text, entities), "HTML"}

        {"markdown", "html"} ->
          {FormatConverter.markdown_to_html(text), "HTML"}

        {_, "markdown_v2"} ->
          {FormatConverter.escape_markdown_v2(text), "MarkdownV2"}

        {_, "markdown"} ->
          {FormatConverter.escape_markdown(text), "Markdown"}

        _ ->
          {FormatConverter.escape_html(text), "HTML"}
      end

    chunks = FormatConverter.chunk_message(formatted, max_chunk)

    {:ok,
     %{
       formatted_text: formatted,
       parse_mode: parse_mode,
       chunks: chunks,
       chunk_count: length(chunks)
     }}
  end

  def handler(_, _), do: {:error, "Invalid input: expected text"}
end
