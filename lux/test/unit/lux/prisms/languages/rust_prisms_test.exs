defmodule Lux.Prisms.Languages.RustPrismsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Languages.Rust.BenchmarkPrism
  alias Lux.Prisms.Languages.Rust.CompilePrism
  alias Lux.Prisms.Languages.Rust.ErrorPrism
  alias Lux.Prisms.Languages.Rust.ExecutePrism
  alias Lux.Prisms.Languages.Rust.TypeBridgePrism

  describe "ExecutePrism" do
    test "executes registered native function" do
      inputs = %{
        "function" => "math.fibonacci",
        "args" => %{"n" => 10}
      }

      assert {:ok, result} = ExecutePrism.handler(inputs, %{})
      assert result.result == 55
      assert result.success == true
      assert result.function == "math.fibonacci"
    end
  end

  describe "TypeBridgePrism" do
    test "bridges map with atoms to string-keyed map" do
      inputs = %{
        "payload" => %{name: "Lux", version: 1}
      }

      assert {:ok, result} = TypeBridgePrism.handler(inputs, %{})
      assert result.detected_type == "map"
      assert result.compatible_payload["name"] == "Lux"
      assert result.valid == true
    end
  end

  describe "CompilePrism" do
    test "verifies priv/rust project structure" do
      assert {:ok, result} = CompilePrism.handler(%{}, %{})
      assert result.cargo_toml_exists == true
      assert result.src_exists == true
      assert result.status == "ready"
    end
  end

  describe "BenchmarkPrism" do
    test "benchmarks native function iterations" do
      inputs = %{
        "function" => "math.fibonacci",
        "args" => %{"n" => 15},
        "iterations" => 20
      }

      assert {:ok, result} = BenchmarkPrism.handler(inputs, %{})
      assert result.iterations == 20
      assert result.total_time_us > 0
      assert result.result == 610
    end
  end

  describe "ErrorPrism" do
    test "catches function not found" do
      assert {:ok, result} = ErrorPrism.handler(%{"trigger" => "not_found"}, %{})
      assert result.caught_error == true
      assert result.error_type == "function_not_found"
    end

    test "catches invalid argument" do
      assert {:ok, result} = ErrorPrism.handler(%{"trigger" => "invalid_arg"}, %{})
      assert result.caught_error == true
      assert result.error_type == "invalid_argument"
    end
  end
end
