defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Test runner for Rust code in the Lux framework.

  Integrates with cargo test and provides a seamless Rust testing experience
  from Elixir, similar to how `mix python.test` works for Python tests.

  ## Usage

      Lux.Rust.TestRunner.run()
      Lux.Rust.TestRunner.run(verbose: true, filter: "types")
      Lux.Rust.TestRunner.run(coverage: true)
  """

  alias Lux.Rust.Coverage

  @rust_project_path Path.expand("../../../priv/rust", __DIR__)

  @type run_option ::
          {:verbose, boolean()}
          | {:filter, String.t()}
          | {:coverage, boolean()}
          | {:coverage_output, String.t()}
          | {:locked, boolean()}
          | {:features, String.t()}
          | {:release, boolean()}

  @type run_options :: [run_option()]

  @type test_result :: %{
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          ignored: non_neg_integer(),
          measured: non_neg_integer(),
          filtered_out: non_neg_integer(),
          total: non_neg_integer(),
          success: boolean(),
          output: String.t(),
          duration_ms: float()
        }

  @doc """
  Runs cargo test in the Rust project directory.

  ## Options
    * `:verbose` — show detailed test output (default: false)
    * `:filter` — run tests matching the given name pattern
    * `:coverage` — generate coverage report (default: false)
    * `:coverage_output` — coverage output directory (default: "cover/rust")
    * `:locked` — use `--locked` flag for cargo test (default: false)
    * `:features` — comma-separated feature flags to enable
    * `:release` — run tests in release mode (default: false)

  ## Returns
    * `{:ok, result}` — tests ran successfully, result is a test_result map
    * `{:error, reason}` — something went wrong

  ## Examples

      iex> {:ok, result} = Lux.Rust.TestRunner.run()
      iex> is_integer(result.passed)
      true

      iex> {:ok, result} = Lux.Rust.TestRunner.run(verbose: true, filter: "crypto")
      iex> result.success
      true
  """
  @spec run(run_options()) :: {:ok, test_result()} | {:error, String.t()}
  def run(opts \\ []) do
    rust_dir = rust_project_path()
    args = build_cargo_args(opts)
    verbose = Keyword.get(opts, :verbose, false)

    start_time = System.monotonic_time(:millisecond)

    case System.cmd("cargo", ["test"] ++ args,
           cd: rust_dir,
           stderr_to_stdout: true,
           env: test_env(opts)) do
      {output, 0} ->
        duration = System.monotonic_time(:millisecond) - start_time
        result = parse_test_results(output, duration, verbose)
        {:ok, result}

      {output, exit_code} ->
        if verbose, do: IO.puts(output)

        duration = System.monotonic_time(:millisecond) - start_time
        result = parse_test_results(output, duration, verbose)
        {:error, "Tests failed with exit code #{exit_code}", result}

      :timeout ->
        {:error, "cargo test timed out"}
    end
  rescue
    e in RuntimeError ->
      {:error, "Failed to run cargo: #{Exception.message(e)}"}
  end

  @doc """
  Same as run/1 but returns only the test result or raises on error.
  """
  @spec run!(run_options()) :: test_result() | no_return()
  def run!(opts \\ []) do
    case run(opts) do
      {:ok, result} -> result
      {:error, reason, result} -> raise "Rust tests failed: #{reason}\n#{result.output}"
      {:error, reason} -> raise "Failed to run Rust tests: #{reason}"
    end
  end

  @doc """
  Checks if cargo is available in the system PATH.
  """
  @spec cargo_available?() :: boolean()
  def cargo_available? do
    System.find_executable("cargo") != nil
  end

  @doc """
  Returns the path to the Rust project directory.
  """
  @spec rust_project_path() :: String.t()
  def rust_project_path, do: @rust_project_path

  @doc """
  Lists available Rust tests without running them.
  """
  @spec list_tests(keyword()) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_tests(opts \\ []) do
    rust_dir = rust_project_path()
    filter = Keyword.get(opts, :filter)

    case System.cmd("cargo", ["test", "--", "--list"],
           cd: rust_dir, stderr_to_stdout: true) do
      {output, 0} ->
        tests =
          output
          |> String.split("\n")
          |> Enum.filter(&String.starts_with?(&1, "    "))
          |> Enum.map(&String.trim/1)
          |> then(fn tests ->
            if filter do
              Enum.filter(tests, &String.contains?(&1, filter))
            else
              tests
            end
          end)

        {:ok, tests}

      {output, _} ->
        {:error, "Failed to list tests: #{String.slice(output, 0, 200)}"}
    end
  end

  @doc """
  Returns the count of available Rust tests.
  """
  @spec test_count() :: {:ok, non_neg_integer()} | {:error, String.t()}
  def test_count do
    case list_tests() do
      {:ok, tests} -> {:ok, length(tests)}
      {:error, _} = error -> error
    end
  end

  defp build_cargo_args(opts) do
    args = []

    args = if Keyword.get(opts, :locked, false), do: args ++ ["--locked"], else: args
    args = if Keyword.get(opts, :release, false), do: args ++ ["--release"], else: args

    args = if feature = Keyword.get(opts, :features),
      do: args ++ ["--features", feature],
      else: args

    if filter = Keyword.get(opts, :filter) do
      args ++ [filter, "--", "--nocapture"]
    else
      args
    end
  end

  defp test_env(opts) do
    env =
      if Keyword.get(opts, :coverage, false) do
        [
          {"CARGO_INCREMENTAL", "0"},
          {"RUSTFLAGS", "-Cinstrument-coverage"},
          {"LLVM_PROFILE_FILE", "rust-test-coverage-%p-%m.profraw"}
        ]
      else
        []
      end

    env ++ [{"RUST_BACKTRACE", "1"}]
  end

  defp parse_test_results(output, duration, verbose) do
    if verbose, do: IO.puts(output)

    regex = ~r/test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out/

    case Regex.run(regex, output) do
      [_, status, passed, failed, ignored, measured, filtered] ->
        passed = String.to_integer(passed)
        failed = String.to_integer(failed)
        ignored = String.to_integer(ignored)
        measured = String.to_integer(measured)
        filtered = String.to_integer(filtered)

        %{
          passed: passed,
          failed: failed,
          ignored: ignored,
          measured: measured,
          filtered_out: filtered,
          total: passed + failed + ignored + measured,
          success: status == "ok" and failed == 0,
          output: output,
          duration_ms: duration / 1.0
        }

      nil ->
        %{
          passed: 0,
          failed: 0,
          ignored: 0,
          measured: 0,
          filtered_out: 0,
          total: 0,
          success: false,
          output: output,
          duration_ms: duration / 1.0
        }
    end
  end
end
