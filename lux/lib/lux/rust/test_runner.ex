defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Integration between Rust tests and Elixir's mix test.

  Provides utilities for running Rust tests from within ExUnit,
  capturing output, and reporting results alongside Elixir tests.

  ## Usage

  In your test file:

      defmodule MyRustTest do
        use ExUnit.Case
        import Lux.Rust.TestRunner

        test "rust tests pass" do
          assert_rust_tests_pass()
        end

        test "specific rust test" do
          assert_rust_test_pass("test_json_roundtrip")
        end
      end
  """

  @crate_path Path.expand("../../../native/lux_native", __DIR__)

  @doc """
  Run all Rust tests and assert they pass.
  Returns `{:ok, output}` or raises on failure.
  """
  def assert_rust_tests_pass(crate_path \\ @crate_path) do
    case run_cargo_test(crate_path) do
      {output, 0} -> {:ok, output}
      {output, code} ->
        raise ExUnit.AssertionError,
          message: "Rust tests failed (exit code #{code}):\n#{output}"
    end
  end

  @doc """
  Run a specific Rust test by name.
  """
  def assert_rust_test_pass(test_name, crate_path \\ @crate_path) do
    case run_cargo_test(crate_path, test_name) do
      {output, 0} -> {:ok, output}
      {output, code} ->
        raise ExUnit.AssertionError,
          message: "Rust test '#{test_name}' failed (exit code #{code}):\n#{output}"
    end
  end

  @doc """
  Run cargo test and return `{output, exit_code}`.
  """
  def run_cargo_test(crate_path \\ @crate_path, filter \\ nil) do
    args = ["test", "--manifest-path", Path.join(crate_path, "Cargo.toml")]
    args = if filter, do: args ++ ["--", filter], else: args
    System.cmd("cargo", args, stderr_to_stdout: true)
  end

  @doc """
  Parse cargo test output and return structured results.
  """
  def parse_results(output) when is_binary(output) do
    lines = String.split(output, "\n")

    tests = lines
    |> Enum.filter(&String.contains?(&1, "... "))
    |> Enum.map(fn line ->
      cond do
        String.contains?(line, "... ok") ->
          name = line |> String.split("...") |> hd() |> String.trim() |> String.replace("test ", "")
          %{name: name, status: :passed}
        String.contains?(line, "... FAILED") ->
          name = line |> String.split("...") |> hd() |> String.trim() |> String.replace("test ", "")
          %{name: name, status: :failed}
        true -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    summary_line = Enum.find(lines, &String.contains?(&1, "test result"))

    %{
      tests: tests,
      passed: Enum.count(tests, &(&1.status == :passed)),
      failed: Enum.count(tests, &(&1.status == :failed)),
      summary: summary_line
    }
  end

  @doc """
  Check if Rust toolchain is available.
  """
  def rust_available? do
    case System.cmd("cargo", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
