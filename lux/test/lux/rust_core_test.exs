defmodule Lux.RustCoreTest do
  use ExUnit.Case
  alias Lux.RustCore

  describe "add/2" do
    test "adds two numbers correctly" do
      assert RustCore.add(5, 10) == 15
    end

    test "handles negative numbers" do
      assert RustCore.add(-5, -10) == -15
      assert RustCore.add(-5, 10) == 5
    end
  end

  describe "compute_complex_task/1" do
    test "processes valid string data successfully" do
      assert {:ok, "Processed: valid data"} = RustCore.compute_complex_task("valid data")
    end

    test "returns error tuple for empty data" do
      assert {:error, "Type conversion error: Data cannot be empty"} =
               RustCore.compute_complex_task("")
    end
  end
end
