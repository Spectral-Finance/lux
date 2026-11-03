defmodule Lux.Prisms.Llm.Perplexity.CitationPrism do
  @moduledoc """
  A prism for formatting raw citation URLs into structured references or markdown footnotes.
  """

  use Lux.Prism,
    name: "Perplexity Citation Formatter",
    description: "Formats and validates web source citations into markdown footnotes or structured data",
    input_schema: %{
      type: :object,
      properties: %{
        citations: %{
          type: :array,
          items: %{type: :string},
          description: "List of URL citations"
        },
        content: %{
          type: :string,
          description: "Optional generated content to append footnotes to"
        }
      },
      required: ["citations"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer},
        references: %{type: :array},
        footnotes_markdown: %{type: :string},
        annotated_content: %{type: [:string, :null]}
      },
      required: ["count", "references", "footnotes_markdown"]
    }

  alias Lux.LLM.Perplexity.Citations

  @impl true
  def handler(inputs, _context) do
    raw_citations = Map.get(inputs, "citations") || Map.get(inputs, :citations, [])
    content = Map.get(inputs, "content") || Map.get(inputs, :content)

    parsed = Citations.parse_citations(raw_citations)
    footnotes = Citations.format_footnotes(parsed)

    annotated_content =
      if is_binary(content) and content != "" and footnotes != "" do
        "#{content}\n\n### References\n#{footnotes}"
      else
        content
      end

    references =
      Enum.map(parsed, fn c ->
        %{index: c.index, url: c.url, domain: c.domain}
      end)

    {:ok,
     %{
       count: length(references),
       references: references,
       footnotes_markdown: footnotes,
       annotated_content: annotated_content
     }}
  end
end
