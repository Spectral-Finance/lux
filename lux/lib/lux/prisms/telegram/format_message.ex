defmodule Lux.Prisms.Telegram.FormatMessage do
  @moduledoc """
  A prism that formats text for Telegram MarkdownV2 or HTML.
  """
  use Lux.Prism,
    name: "Format Telegram Message",
    description: "Formats text for Telegram MarkdownV2 or HTML, handling escaping and styles.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string},
        mode: %{type: :string, enum: ["markdown", "html"]},
        style: %{type: :string, enum: ["bold", "italic", "code", "escape", "link"]},
        url: %{type: :string, description: "Required if style is link"}
      },
      required: ["text", "mode", "style"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        formatted_text: %{type: :string}
      }
    }

  def handler(%{"text" => text, "mode" => mode, "style" => style} = input, _ctx) do
    parsed_mode = String.to_existing_atom(mode)
    
    result = case style do
      "bold" -> Lux.Integrations.Telegram.Formatter.bold(text, parsed_mode)
      "italic" -> Lux.Integrations.Telegram.Formatter.italic(text, parsed_mode)
      "code" -> Lux.Integrations.Telegram.Formatter.code(text, parsed_mode)
      "escape" -> 
        if parsed_mode == :markdown, do: Lux.Integrations.Telegram.Formatter.escape_markdown(text), else: Lux.Integrations.Telegram.Formatter.escape_html(text)
      "link" -> Lux.Integrations.Telegram.Formatter.link(text, Map.get(input, "url", ""), parsed_mode)
    end
    
    {:ok, %{"formatted_text" => result}}
  end
end
