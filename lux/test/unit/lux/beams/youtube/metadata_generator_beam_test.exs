defmodule Lux.Beams.YouTube.MetadataGeneratorBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.YouTube.MetadataGeneratorBeam

  describe "MetadataGeneratorBeam" do
    test "output structure matches metadata schema" do
      beam = MetadataGeneratorBeam.view()
      
      assert %{
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
      } = beam.output_schema
    end
  end
end
