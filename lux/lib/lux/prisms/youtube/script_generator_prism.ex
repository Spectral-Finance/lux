defmodule Lux.Prisms.YouTube.ScriptGeneratorPrism do
  @moduledoc """
  Generates a YouTube video script from a prompt using an LLM.
  """
  use Lux.Prism,
    name: "YouTube Script Generator",
    description: "Generates a YouTube video script from a prompt",
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
        script: %{type: :string}
      },
      required: ["script"]
    }

  alias Lux.LLM

  def handler(input, _ctx) do
    prompt = input[:prompt] || input["prompt"]
    config = Application.get_env(:lux, :llm_config, %{})
    full_prompt = "You are a professional YouTube script writer. Generate a script for the following prompt:\n\n#{prompt}"

    case LLM.call(full_prompt, [], config) do
      {:ok, response} ->
        content = response.payload.content
        script = if is_map(content), do: content["script"] || content[:script], else: content
        {:ok, %{script: script}}

      error ->
        error
    end
  end
end
