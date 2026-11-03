defmodule Lux.Beams.Languages.CargoBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Languages.Rust.Cargo.CargoDependencyPipelineBeam
  alias Lux.Rust.Cargo

  describe "CargoDependencyPipelineBeam" do
    test "verifies beam definition and metadata" do
      assert CargoDependencyPipelineBeam.name() == "Cargo Dependency Management Pipeline"
      assert is_map(CargoDependencyPipelineBeam.input_schema())
      assert is_map(CargoDependencyPipelineBeam.output_schema())
      assert CargoDependencyPipelineBeam.input_schema().required == ["crate"]
    end

    test "executes full pipeline sequence and cleans up added crate" do
      inputs = %{
        crate: "temp_pipeline_crate",
        version: "0.2.0",
        release: true
      }

      assert {:ok, result, execution_log} = CargoDependencyPipelineBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.crate == "temp_pipeline_crate"
      assert result.compiled == true

      # Clean up test crate
      Cargo.remove_dependency("temp_pipeline_crate")
    end
  end
end
