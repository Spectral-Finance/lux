defmodule Lux.Beams.YouTube.ScriptGeneratorBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.YouTube.ScriptGeneratorBeam

  describe "ScriptGeneratorBeam" do
    test "output structure matches script schema" do
      beam = ScriptGeneratorBeam.view()
      
      assert %{
        type: :object,
        properties: %{script: %{type: :string}},
        required: ["script"]
      } = beam.output_schema
    end
  end
end
