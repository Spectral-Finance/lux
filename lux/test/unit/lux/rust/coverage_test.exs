defmodule Lux.Rust.CoverageTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Rust.Coverage

  describe "detect_coverage_tool/0" do
    test "returns a string or nil" do
      tool = Coverage.detect_coverage_tool()
      assert is_nil(tool) or is_binary(tool)
    end
  end

  describe "coverage_available?/0" do
    test "returns a boolean" do
      assert is_boolean(Coverage.coverage_available?())
    end
  end

  describe "summary/1" do
    test "returns error when no coverage data exists" do
      result = Coverage.summary(coverage_dir: "/tmp/nonexistent_coverage_dir")
      assert {:error, _} = result
    end
  end

  describe "generate/1" do
    @tag :slow
    test "generates coverage report when tools available" do
      if Coverage.coverage_available?() do
        case Coverage.generate() do
          {:ok, path} ->
            assert is_binary(path)
            assert String.contains?(path, "cover")

          {:error, _} ->
            :ok
        end
      end
    end
  end
end
