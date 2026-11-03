defmodule Lux.Beams.Languages.RustComponentsBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Languages.Rust.Components.RustComponentPipelineBeam

  describe "RustComponentPipelineBeam" do
    test "has expected metadata" do
      assert RustComponentPipelineBeam.name() == "RustComponentPipelineBeam" ||
             RustComponentPipelineBeam.name() == "Rust Component Pipeline Beam"
      assert is_binary(RustComponentPipelineBeam.description())
      assert is_map(RustComponentPipelineBeam.input_schema())
      assert is_map(RustComponentPipelineBeam.output_schema())
    end

    test "beam steps are configured properly" do
      steps = RustComponentPipelineBeam.steps()
      assert is_list(steps)
      assert length(steps) >= 3

      step_ids = Enum.map(steps, & &1.id)
      assert :sync_schema in step_ids
      assert :init_lifecycle in step_ids
      assert :invoke_component in step_ids
      assert :teardown_lifecycle in step_ids
    end
  end
end
