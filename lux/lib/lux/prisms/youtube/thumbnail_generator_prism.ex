defmodule Lux.Prisms.YouTube.ThumbnailGeneratorPrism do
  @moduledoc """
  Generates a YouTube video thumbnail from a prompt using an LLM image model (DALL-E simulated).
  """
  use Lux.Prism,
    name: "YouTube Thumbnail Generator",
    description: "Generates a YouTube video thumbnail from a prompt",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{type: :string}
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        thumbnail_url: %{type: :string}
      },
      required: ["thumbnail_url"]
    }

  alias Lux.LLM

  def handler(input, _ctx) do
    prompt = input[:prompt] || input["prompt"]
    config = Application.get_env(:lux, :llm_config, %{})
    
    full_prompt = """
    You are an AI image generation wrapper. The user wants to generate a thumbnail.
    Since this is a simulated DALL-E call via a text LLM for the pipeline test, simply return a fake URL based on the prompt.
    Reply ONLY with a JSON object in this exact format:
    {
      "thumbnail_url": "https://example.com/thumbnails/generated_image.png"
    }

    Prompt:
    #{prompt}
    """

    case LLM.call(full_prompt, [], config) do
      {:ok, response} ->
        content = response.payload.content
        thumbnail_url = content["thumbnail_url"] || content[:thumbnail_url] || "https://example.com/thumbnail.png"
        {:ok, %{thumbnail_url: thumbnail_url}}

      error ->
        error
    end
  end
end
