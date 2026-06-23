defmodule Lux.Beams.YouTube.ThumbnailGeneratorBeam do
  @moduledoc """
  Chains steps to generate a YouTube video thumbnail.
  """
  use Lux.Beam,
    name: "YouTube Thumbnail Generator Beam",
    description: "Generates a YouTube video thumbnail URL",
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

  sequence do
    step(:generate_thumbnail, Lux.Prisms.YouTube.ThumbnailGeneratorPrism, %{prompt: :prompt})
  end
end
