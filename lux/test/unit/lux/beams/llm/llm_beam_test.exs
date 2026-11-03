defmodule Lux.Beams.LlmBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Llm.LlmInferenceBeam

  describe "LlmInferenceBeam" do
    test "defines beam structure and schema correctly" do
      assert LlmInferenceBeam.name() == "LLM Inference Orchestration Beam"
      assert is_map(LlmInferenceBeam.input_schema())
      assert is_map(LlmInferenceBeam.output_schema())
    end
  end
end
