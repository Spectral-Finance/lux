defmodule Lux.RustTest do
  @moduledoc """
  Provides functions for running Rust tests and integrating with the Lux test infrastructure.

  This module allows you to run Rust tests from Elixir, parse test results,
  and integrate coverage reporting. It mirrors the patterns established by
  `Lux.Python` and `Lux.NodeJS` for language support.

  ## Examples

      iex> Lux.RustTest.run()
      {:ok, %{passed: 5, failed: 0, total: 5}}

      iex> Lux.RustTest.run(path: "priv/rust/my_crate")
      {:ok, %{passed: 3, failed: 1, total: 4}}
  """

  @type test_result :: %{
          optional(:passed) => non_neg_integer(),
          optional(:failed) => non_neg_integer(),
          optional(:total) => non_neg_integer(),
          optional(:output) => String.t()
        }

  @type run_option ::
          {:path, String.t()}
          | {:verbose, boolean()}
          | {:release, boolean()}
          | {:filter, String.t()}
          | {:coverage, boolean()}

  @type run_options :: [run_option()]

  @default_rust_dir "priv/rust"

  @doc """
  Returns the default Rust projects directory path.

  ## Examples

      iex> Lux.RustTest.default_dir()
      "priv/rust"
  """
  @spec default_dir() :: String.t()
  def default_dir, do: @default_rust_dir

  @doc """
  Returns the absolute path to a Rust project directory.

  ## Examples

      iex> Lux.RustTest.project_path("lux_rust_testing")
      "/path/to/lux/priv/rust/lux_rust_testing"
  """
  @spec project_path(String.t()) :: String.t()
  def project_path(project_name) do
    Path.join([Application.app_dir(:lux, @default_rust_dir), project_name])
  end

  @doc """
  Runs Rust tests for a project in priv/rust.

  ## Options

    * `:path` - Path to the Rust project (default: first project found in priv/rust)
    * `:verbose` - Show detailed test output (default: false)
    * `:release` - Run tests in release mode (default: false)
    * `:filter` - Only run tests matching a pattern (e.g., "test_foo")
    * `:coverage` - Generate coverage report via cargo-tarpaulin (default: false)

  ## Examples

      iex> Lux.RustTest.run()
      {:ok, %{passed: 5, failed: 0, total: 5}}

      iex> Lux.RustTest.run(verbose: true, filter: "integration")
      {:ok, %{passed: 2, failed: 0, total: 2}}

      iex> Lux.RustTest.run(path: "priv/rust/lux_rust_testing")
      {:ok, %{passed: 5, failed: 0, total: 5}}
  """
  @spec run(run_options()) :: {:ok, test_result()} | {:error, String.t()}
  def run(opts \\ []) do
    path = resolve_path(opts[:path])
    verbose = Keyword.get(opts, :verbose, false)
    release = Keyword.get(opts, :release, false)
    filter = Keyword.get(opts, :filter)
    coverage = Keyword.get(opts, :coverage, false)

    with {:ok, _} <- ensure_cargo_installed(),
         {:ok, _} <- ensure_project_exists(path),
         {:ok, output} <- run_cargo_test(path, verbose, release, filter) do
      result = parse_test_output(output)

      if coverage do
        run_coverage(path, verbose)
      end

      {:ok, result}
    end
  end

  @doc """
  Same as `run/1` but returns the result directly or raises on error.

  ## Examples

      iex> Lux.RustTest.run!()
      %{passed: 5, failed: 0, total: 5}

      iex> Lux.RustTest.run!(verbose: true)
      %{passed: 5, failed: 0, total: 5}
  """
  @spec run!(run_options()) :: test_result() | no_return()
  def run!(opts \\ []) do
    case run(opts) do
      {:ok, result} -> result
      {:error, error} -> raise RuntimeError, "Rust tests failed: #{error}"
    end
  end

  @doc """
  Lists all available Rust projects in priv/rust.

  ## Examples

      iex> Lux.RustTest.list_projects()
      ["lux_rust_testing"]
  """
  @spec list_projects() :: {:ok, [String.t()], [String.t()]}
  def list_projects do
    rust_dir = Application.app_dir(:lux, @default_rust_dir)

    if File.exists?(rust_dir) do
      projects =
        rust_dir
        |> File.ls!()
        |> Enum.filter(fn name ->
          candidate = Path.join(rust_dir, name)
          File.dir?(candidate) and File.exists?(Path.join(candidate, "Cargo.toml"))
        end)
        |> Enum.sort()

      {:ok, projects}
    else
      {:ok, []}
    end
  end

  @doc """
  Returns a summary string of the test result.

  ## Examples

      iex> Lux.RustTest.summary(%{passed: 5, failed: 0, total: 5})
      "Rust tests: 5 passed, 0 failed, 5 total"
  """
  @spec summary(test_result()) :: String.t()
  def summary(result) do
    "Rust tests: #{result[:passed]} passed, #{result[:failed]} failed, #{result[:total]} total"
  end

  defp resolve_path(nil) do
    {:ok, projects} = list_projects()

    case projects do
      [] -> {:error, "No Rust projects found in priv/rust"}
      [first | _] -> Path.join(Application.app_dir(:lux, @default_rust_dir), first)
    end
  end

  defp resolve_path(path) when is_binary(path) do
    cond do
      String.starts_with?(path, "/") ->
        path

      String.starts_with?(path, "priv/rust/") ->
        Application.app_dir(:lux, path)

      true ->
        Path.join(Application.app_dir(:lux, @default_rust_dir), path)
    end
  end

  defp ensure_cargo_installed do
    case System.find_executable("cargo") do
      nil -> {:error, "Cargo not found. Please install Rust: https://rustup.rs"}
      path -> {:ok, path}
    end
  end

  defp ensure_project_exists(path) do
    if File.exists?(path) and File.exists?(Path.join(path, "Cargo.toml")) do
      {:ok, path}
    else
      {:error, "No Rust project found at #{path}"}
    end
  end

  defp run_cargo_test(path, verbose, release, filter) do
    args = build_args(verbose, release, filter)

    case System.cmd("cargo", args, cd: path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:ok, output}
    end
  end

  defp build_args(verbose, release, filter) do
    args = ["test"]

    args =
      if release do
        args ++ ["--release"]
      else
        args
      end

    args =
      if verbose do
        args ++ ["--", "--nocapture"]
      else
        args
      end

    if filter do
      args ++ [filter]
    else
      args
    end
  end

  defp run_coverage(path, verbose) do
    case System.find_executable("cargo-tarpaulin") do
      nil ->
        Mix.shell().warn(
          "cargo-tarpaulin not found. Install with: cargo install cargo-tarpaulin"
        )

      _ ->
        args = ["tarpaulin", "--out", "Json", "--output-dir", "coverage"]

        args =
          if verbose do
            args ++ ["--verbose"]
          else
            args
          end

        System.cmd("cargo", args, cd: path)
    end
  end

  defp parse_test_output(output) do
    lines = String.split(output, "\n")

    test_run_line =
      Enum.find(lines, fn line ->
        String.contains?(line, "test result:") or
          String.contains?(line, "running ") and String.contains?(line, "test")
      end)

    cond do
      test_run_line && String.contains?(test_run_line, "test result:") ->
        parse_test_result_line(test_run_line, output)

      true ->
        count_tests_fallback(lines, output)
    end
  end

  defp parse_test_result_line(line, output) do
    pattern = ~r/test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out/

    case Regex.run(pattern, line) do
      [_, _status, passed, failed, _ignored, _measured, _filtered] ->
        passed_count = String.to_integer(passed)
        failed_count = String.to_integer(failed)
        total = passed_count + failed_count

        result = %{
          passed: passed_count,
          failed: failed_count,
          total: total,
          output: output
        }

        result

      nil ->
        count_tests_fallback(String.split(output, "\n"), output)
    end
  end

  defp count_tests_fallback(lines, output) do
    passed =
      lines
      |> Enum.filter(&String.contains?(&1, "test"))
      |> Enum.filter(&String.contains?(&1, "... ok") or String.contains?(&1, "PASSED"))
      |> length()

    failed =
      lines
      |> Enum.filter(&String.contains?(&1, "test"))
      |> Enum.filter(&String.contains?(&1, "... FAILED") or String.contains?(&1, "FAILED"))
      |> length()

    %{passed: passed, failed: failed, total: passed + failed, output: output}
  end
end
