defmodule Lux.Beams.UniversalLLMPipelineBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.LLM.UniversalLLMPipelineBeam

  describe "UniversalLLMPipelineBeam" do
    test "has expected metadata" do
      assert UniversalLLMPipelineBeam.name() == "UniversalLLMPipelineBeam" ||
             UniversalLLMPipelineBeam.name() == "Universal LLM Pipeline Beam"
      assert is_binary(UniversalLLMPipelineBeam.description())
      assert is_map(UniversalLLMPipelineBeam.input_schema())
      assert is_map(UniversalLLMPipelineBeam.output_schema())
    end

    test "beam steps are configured properly" do
      steps = UniversalLLMPipelineBeam.steps()
      assert is_list(steps)
      assert length(steps) >= 3

      step_ids = Enum.map(steps, & &1.id)
      assert :model_selection in step_ids
      assert :execute_llm in step_ids
      assert :record_cost in step_ids
    end
  end
end
