defmodule Lux.Prisms.YouTube.MetadataGeneratorPrism do
  @moduledoc """
  Generates YouTube video metadata from a script using an LLM.
  """
  use Lux.Prism,
    name: "YouTube Metadata Generator",
    description: "Generates YouTube video metadata from a script",
    input_schema: %{
      type: :object,
      properties: %{
        script: %{type: :string}
      },
      required: ["script"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        tags: %{
          type: :array,
          items: %{type: :string}
        }
      },
      required: ["title", "description", "tags"]
    }

  alias Lux.LLM

  def handler(input, _ctx) do
    script = input[:script] || input["script"]
    config = Application.get_env(:lux, :llm_config, %{})
    
    full_prompt = """
    You are a professional YouTube SEO expert. Given the following video script, generate a catchy title, a detailed description, and a list of relevant SEO tags.
    Reply ONLY with a JSON object in this exact format:
    {
      "title": "Your Title Here",
      "description": "Your Description Here",
      "tags": ["tag1", "tag2"]
    }

    Script:
    #{script}
    """

    case LLM.call(full_prompt, [], config) do
      {:ok, response} ->
        content = response.payload.content
        title = content["title"] || content[:title] || ""
        description = content["description"] || content[:description] || ""
        tags = content["tags"] || content[:tags] || []
        {:ok, %{title: title, description: description, tags: tags}}

      error ->
        error
    end
  end
end
