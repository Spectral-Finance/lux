defmodule Lux.Beams.Languages.RustBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Languages.Rust.RustExecutionBeam

  describe "RustExecutionBeam" do
    test "verifies beam definition and metadata" do
      assert RustExecutionBeam.name() == "Rust Execution Pipeline"
      assert is_map(RustExecutionBeam.input_schema())
      assert is_map(RustExecutionBeam.output_schema())
      assert RustExecutionBeam.input_schema().required == ["function", "args"]
    end

    test "executes full pipeline: type validation -> execution -> benchmarking" do
      inputs = %{
        function: "math.fibonacci",
        args: %{"n" => 12},
        iterations: 10
      }

      assert {:ok, result, execution_log} = RustExecutionBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.result == 144
      assert result.total_time_us > 0
      assert result.avg_time_us > 0.0
    end
  end
end
