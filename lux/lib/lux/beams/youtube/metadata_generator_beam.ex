defmodule Lux.Beams.YouTube.MetadataGeneratorBeam do
  @moduledoc """
  Chains steps to generate YouTube video metadata (Title, Description, Tags).
  """
  use Lux.Beam,
    name: "YouTube Metadata Generator Beam",
    description: "Generates YouTube video metadata",
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

  sequence do
    step(:generate_metadata, Lux.Prisms.YouTube.MetadataGeneratorPrism, %{script: :script})
  end
end
