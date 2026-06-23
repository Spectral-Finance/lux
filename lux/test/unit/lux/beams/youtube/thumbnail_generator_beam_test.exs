defmodule Lux.Beams.YouTube.ThumbnailGeneratorBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.YouTube.ThumbnailGeneratorBeam

  describe "ThumbnailGeneratorBeam" do
    test "output structure matches thumbnail schema" do
      beam = ThumbnailGeneratorBeam.view()
      
      assert %{
        type: :object,
        properties: %{
          thumbnail_url: %{type: :string}
        },
        required: ["thumbnail_url"]
      } = beam.output_schema
    end
  end
end
