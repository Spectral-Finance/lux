defmodule Lux.Prisms.Languages.RustTestingPrismsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Languages.Rust.Testing.AssertPrism
  alias Lux.Prisms.Languages.Rust.Testing.BenchmarkRunnerPrism
  alias Lux.Prisms.Languages.Rust.Testing.CoveragePrism
  alias Lux.Prisms.Languages.Rust.Testing.FixturePrism
  alias Lux.Prisms.Languages.Rust.Testing.RunTestsPrism

  describe "RunTestsPrism" do
    test "runs tests and captures metrics" do
      assert {:ok, result} = RunTestsPrism.handler(%{}, %{})
      assert result.passed > 0
      assert result.success == true
    end
  end

  describe "CoveragePrism" do
    test "calculates coverage percentage" do
      assert {:ok, result} = CoveragePrism.handler(%{"passed" => 9, "total" => 10}, %{})
      assert result.coverage_percentage == 90.0
      assert result.meets_threshold == true
      assert result.status == "pass"
    end
  end

  describe "FixturePrism" do
    test "generates vector fixtures" do
      assert {:ok, result} = FixturePrism.handler(%{"fixture_name" => "vectors", "size" => 4}, %{})
      assert result.fixture_name == "vectors"
      assert length(result.fixture_data["a"]) == 4
    end
  end

  describe "AssertPrism" do
    test "evaluates correct assertion" do
      inputs = %{
        "function" => "math.fibonacci",
        "args" => %{"n" => 10},
        "expected" => 55
      }

      assert {:ok, result} = AssertPrism.handler(inputs, %{})
      assert result.passed == true
    end
  end

  describe "BenchmarkRunnerPrism" do
    test "runs benchmarks" do
      inputs = %{
        "function" => "math.fibonacci",
        "args" => %{"n" => 10},
        "iterations" => 15
      }

      assert {:ok, result} = BenchmarkRunnerPrism.handler(inputs, %{})
      assert result.iterations == 15
      assert result.total_us > 0
    end
  end
end
