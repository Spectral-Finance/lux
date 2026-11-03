defmodule Lux.Beams.Languages.RustTestingBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Languages.Rust.Testing.RustTestSuiteBeam

  describe "RustTestSuiteBeam" do
    test "verifies beam definition and metadata" do
      assert RustTestSuiteBeam.name() == "Rust Test Suite Pipeline"
      assert is_map(RustTestSuiteBeam.input_schema())
      assert is_map(RustTestSuiteBeam.output_schema())
    end

    test "executes full pipeline sequence" do
      inputs = %{
        fixture_name: "vectors",
        size: 5
      }

      assert {:ok, result, execution_log} = RustTestSuiteBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.success == true
      assert result.passed > 0
    end
  end
end
