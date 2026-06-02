defmodule Lux.Rust.TestRunnerTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Rust.TestRunner

  describe "cargo_available?/0" do
    test "returns true when cargo is in PATH" do
      if System.find_executable("cargo") do
        assert TestRunner.cargo_available?()
      end
    end

    test "returns a boolean" do
      assert is_boolean(TestRunner.cargo_available?())
    end
  end

  describe "rust_project_path/0" do
    test "returns a string ending with priv/rust" do
      path = TestRunner.rust_project_path()
      assert is_binary(path)
      assert String.contains?(path, "priv/rust")
    end
  end

  describe "run/1" do
    @tag :slow
    test "runs rust tests and returns results" do
      if TestRunner.cargo_available?() and File.dir?(TestRunner.rust_project_path()) do
        case TestRunner.run() do
          {:ok, result} ->
            assert is_map(result)
            assert is_integer(result.passed)
            assert is_integer(result.failed)
            assert is_integer(result.total)
            assert is_float(result.duration_ms)
            assert is_binary(result.output)

          {:error, reason, _result} ->
            flunk("Rust tests failed: #{reason}")

          {:error, reason} ->
            flunk("Failed to run: #{reason}")
        end
      end
    end

    @tag :slow
    test "runs with verbose flag" do
      if TestRunner.cargo_available?() and File.dir?(TestRunner.rust_project_path()) do
        case TestRunner.run(verbose: true) do
          {:ok, result} ->
            assert result.success
            assert is_binary(result.output)

          {:error, _, _} ->
            :ok
        end
      end
    end

    @tag :slow
    test "runs with filter" do
      if TestRunner.cargo_available?() and File.dir?(TestRunner.rust_project_path()) do
        case TestRunner.run(filter: "test_type") do
          {:ok, result} ->
            assert is_map(result)
            assert result.total >= 0

          {:error, _, _} ->
            :ok
        end
      end
    end
  end

  describe "list_tests/1" do
    @tag :slow
    test "lists available Rust tests" do
      if TestRunner.cargo_available?() and File.dir?(TestRunner.rust_project_path()) do
        case TestRunner.list_tests() do
          {:ok, tests} ->
            assert is_list(tests)

          {:error, _} ->
            :ok
        end
      end
    end
  end

  describe "test_count/0" do
    @tag :slow
    test "returns a count of available tests" do
      if TestRunner.cargo_available?() and File.dir?(TestRunner.rust_project_path()) do
        case TestRunner.test_count() do
          {:ok, count} ->
            assert is_integer(count)
            assert count >= 0

          {:error, _} ->
            :ok
        end
      end
    end
  end
end
