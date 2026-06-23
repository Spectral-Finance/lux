defmodule Lux.Beams.YouTube.ScriptGeneratorBeam do
  @moduledoc """
  Chains steps to generate a YouTube video script.
  """
  use Lux.Beam,
    name: "YouTube Script Generator Beam",
    description: "Generates a YouTube video script",
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

  sequence do
    step(:generate_script, Lux.Prisms.YouTube.ScriptGeneratorPrism, %{prompt: :prompt})
  end
end
