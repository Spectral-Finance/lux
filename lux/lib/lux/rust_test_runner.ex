defmodule Lux.RustTestRunner do
  @moduledoc """
  Rust Test Runner for Lux - Integration with mix test for bounty #102.

  Provides a complete Rust test runner that integrates with the existing
  Elixir test infrastructure, with coverage reporting,
  cross-language test utilities, and test fixtures.

  ## Usage

      alias Lux.RustTestRunner

      # Run all Rust tests
      {:ok, results} = RustTestRunner.run()

      # Run specific test module
      {:ok, results} = RustTestRunner.run(["--test", "some_test"])

      # Run with coverage
      {:ok, coverage} = RustTestRunner.coverage()

      # Get test summary
      summary = RustTestRunner.summary(results)

  ## Mix Integration

  ### Independent Mix Task

  Run Rust tests independently via:

      mix rust.test

  This invokes Lux.RustTestRunner.run/1 through Mix.Tasks.Rust.Test.

  ### ExUnit Integration

  An ExUnit integration test in `test/integration/rust_test_runner_integration_test.exs
  automatically calls Lux.RustTestRunner.run() as part of mix test,
  ensuring Rust tests execute alongside Elixir tests.

  ## Cargo Project Resolution

  The `run/1` and `coverage/0` functions resolve the Rust project path
  from the Lux repository root. It searches:

  - lux/rust/ (subcrate)
  - priv/rust/ (priv Rust project)

  Returns {:ok, path} if Cargo.toml is found, {:error, reason} otherwise.

  ## Coverage Reporting

  Uses cargo-tarpaulin for coverage. Install with:

      cargo install cargo-tarpaulin

  Run coverage:

      RustTestRunner.coverage()

  ## Cross-Language Test Utilities

  Available via `test_utils/0`:

      utils = RustTestRunner.test_utils()
      # => [:assert_exit_code_zero, :assert_test_output_contains, :assert_no_failures]

  ## Test Fixtures

  Create and load JSON fixtures:

      RustTestRunner.create_fixture("my_fixture", %{key: "value"})
      {:ok, data} = RustTestRunner.load_fixture("my_fixture")

  ## Rust Test Example

  A minimal Rust crate is included at lux/rust/:

      // lux/rust/src/lib.rs
      pub fn add(a: i32, b: i32) -> i32 {
          a + b
      }

      #[cfg(test)]
      mod tests {
          use super::*;

          #[test]
          fn test_add() {
              assert_eq!(add(2, 3), 5);
          }
      }

  Run with:

      mix rust.test
  """

  require Logger

  @doc "Runs all Rust tests via cargo test."
  @spec run(list(String.t())) :: {:ok, map()} | {:error, String.t()}
  def run(tests \\ []) do
    case resolve_cargo_project_path() do
      {:ok, project_path} ->
        cmd_args = ["test", "--all"] ++ tests

        case System.cmd("cargo", cmd_args,
               cd: project_path,
               stderr_to_stdout: true
             ) do
          {output, 0} ->
            case parse_cargo_output(output) do
              {:ok, parsed} ->
                {:ok, parsed}

              {:error, reason} ->
                {:error, "Cargo returned 0 but output could not be parsed: #{reason}"}
            end

          {output, exit_code} ->
            Logger.error("Rust tests failed with exit code #{exit_code}")
            {:error,
             "Tests failed (exit #{exit_code}): #{String.trim(output) |> String.slice(0, 500)}"}
        end

      {:error, reason} ->
        {:error, "Cannot locate Rust project: #{reason}"}
    end
  end

  @doc "Generates coverage report via cargo tarpaulin."
  @spec coverage() :: {:ok, map()} | {:error, String.t()}
  def coverage do
    case resolve_cargo_project_path() do
      {:ok, project_path} ->
        case System.cmd("cargo", ["tarpaulin", "--version"],
               cd: project_path,
               stderr_to_stdout: true
             ) do
          {_output, 0} ->
            cmd_args = [
              "tarpaulin",
              "--out", "Xml",
              "--out", "Html",
              "--engine", "llvm",
              "--follow-tests",
              "--timeout", "120"
            ]

            case System.cmd("cargo", cmd_args,
                   cd: project_path, stderr_to_stdout: true
                 ) do
              {output, 0} ->
                case parse_coverage_output(output) do
                  {:ok, cov} -> {:ok, cov}
                  {:error, reason} -> {:error, "Coverage parsing failed: #{reason}"}
                end

              {output, exit_code} ->
                {:error,
                 "Coverage failed (exit #{exit_code}): #{String.trim(output) |> String.slice(0, 500)}"}
            end

          {_output, _exit_code} ->
            {:error, "cargo-tarpaulin not found (run: cargo install cargo-tarpaulin)"}
        end

      {:error, reason} ->
        {:error, "Cannot locate Rust project: #{reason}"}
    end
  end

  @doc """
  Resolves the path to the Rust Cargo project within the Lux repository.

  Searches common locations for Cargo.toml:
  - lux/rust/ (subcrate)
  - priv/rust/ (priv Rust project)

  Returns {:ok, path} if found, {:error, reason} otherwise.
  """
  @spec resolve_cargo_project_path() :: {:ok, String.t()} | {:error, String.t()}
  def resolve_cargo_project_path do
    # __DIR__ = lux/lib/lux/
    # Target = lux/rust/ (relative to repo root = lux/)
    # From __DIR__: ../../rust
    base = Path.join([__DIR__, "../../rust"])
    cargo_toml = Path.join(base, "Cargo.toml")

    case File.exists?(cargo_toml) do
      true -> {:ok, base}
      false ->
        priv_path = Path.join([__DIR__, "../../priv/rust"])
        priv_cargo = Path.join(priv_path, "Cargo.toml")
        case File.exists?(priv_cargo) do
          true -> {:ok, priv_path}
          false -> {:error, "No Cargo.toml found in lux/rust/ or priv/rust/"}
        end
    end
  end

  @doc """
  Parses standard cargo test output.

  Matches patterns like:
    test result: ok. 42 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.12s

  Returns {:ok, parsed_map} on success, {:error, reason} when output cannot be parsed
  or represents 0 tests (which indicates cargo failed to find/run any tests).

  Multiple test result lines from different targets are aggregated.
  """
  @spec parse_cargo_output(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_cargo_output(output) do
    matches = Regex.scan(~r/test result: (ok|FAILED)\\.\\s+(\\d+) passed;\\s+(\\d+) failed/, output)

    if matches == [] do
      trimmed = String.trim(output)
      cond do
        trimmed == "" ->
          {:error, "Empty cargo test output - no tests ran or cargo failed"}

        String.contains?(trimmed, "FAILED") ->
          {:error, "Cargo test output contains FAILED but no parseable test result line"}

        true ->
          {:error, "Unrecognized cargo test output format: #{String.slice(trimmed, 0, 200)}"}
      end
    else
      total_passed = Enum.reduce(matches, 0, fn [_, _, passed_str, _], acc ->
        acc + String.to_integer(passed_str)
      end)

      total_failed = Enum.reduce(matches, 0, fn [_, _, _, failed_str], acc ->
        acc + String.to_integer(failed_str)
      end)

      duration =
        Regex.scan(~r/finished in ([\\d.]+)s/, output)
        |> then(fn
          [] -> "unknown"
          [[_, d]] -> d
          _ -> "unknown"
        end)

      if total_passed + total_failed == 0 do
        {:error, "Parsed 0 tests total (passed: #{total_passed}, failed: #{total_failed}) - cargo found no tests to run"}
      else
        {:ok, %{
          tests_passed: total_passed,
          tests_failed: total_failed,
          duration: duration,
          output: String.trim(output)
        }}
      end
    end
  end

  @doc """
  Parses cargo-tarpaulin coverage output.

  Matches patterns like:
    Coverage : 85.7% (120/140 lines)

  Supports both integer (85%) and decimal (85.7%) percentages.
  Returns {:ok, map} on success, {:error, reason} if parsing fails.
  """
  @spec parse_coverage_output(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_coverage_output(output) do
    coverage_pct =
      Regex.run(~r/Coverage\\s*:\\s*([\\d.]+)%/, output)
      |> then(fn
        [_, pct] ->
          if String.contains?(pct, ".") do
            String.to_float(pct)
          else
            String.to_integer(pct) * 1.0
          end
        _ -> nil
      end)

    case coverage_pct do
      nil -> {:error, "No coverage percentage found in output"}
      pct -> {:ok, %{coverage_percentage: pct, output: String.trim(output)}}
    end
  end

  @doc "Returns a test summary map."
  @spec summary(map()) :: map()
  def summary(results) do
    passed = Map.get(results, :tests_passed, 0)
    failed = Map.get(results, :tests_failed, 0)
    total = passed + failed

    %{
      total: total,
      passed: passed,
      failed: failed,
      duration: Map.get(results, :duration, "unknown"),
      coverage: "Run RustTestRunner.coverage() for coverage data"
    }
  end

  @doc "Creates a test fixture for Rust integration testing."
  @spec create_fixture(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def create_fixture(name, data \\ %{}) do
    case :code.priv_dir(:lux) do
      {:error, reason} ->
        {:error, "Cannot determine priv dir for :lux: #{inspect(reason)}"}

      priv_path ->
        fixture_dir = Path.join([priv_path, "rust_test_fixtures"])

        case File.mkdir_p(fixture_dir) do
          :ok ->
            fixture_file = Path.join(fixture_dir, "#{name}.json")
            case File.write(fixture_file, Jason.encode!(data, pretty: true)) do
              :ok -> {:ok, fixture_file}
              {:error, write_reason} -> {:error, "Failed to write fixture: #{write_reason}"}
            end

          {:error, mkdir_reason} ->
            {:error, "Failed to create fixture directory: #{inspect(mkdir_reason)}"}
        end
    end
  end

  @doc "Loads a test fixture by name."
  @spec load_fixture(String.t()) :: {:ok, map()} | {:error, String.t()}
  def load_fixture(name) do
    fixture_dir_result = :code.priv_dir(:lux)

    fixture_file =
      case fixture_dir_result do
        {:error, _} ->
          Path.join(["rust_test_fixtures", "#{name}.json"])

        path ->
          Path.join([path, "rust_test_fixtures", "#{name}.json"])
      end

    case File.read(fixture_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, decode_reason} -> {:error, "Failed to decode fixture JSON: #{decode_reason}"}
        end

      {:error, read_reason} ->
        {:error, "Fixture not found: #{name} (#{inspect(read_reason)})"}
    end
  end

  @doc "Returns cross-language test utility function names."
  @spec test_utils() :: [atom()]
  def test_utils do
    [:assert_exit_code_zero, :assert_test_output_contains, :assert_no_failures]
  end

  @doc """
  Asserts that the test result indicates zero failures.

  Returns true only when all tests passed.
  """
  @spec assert_exit_code_zero({:ok, map()} | {:error, String.t()}) :: boolean()
  def assert_exit_code_zero({:ok, %{tests_failed: 0}}), do: true
  def assert_exit_code_zero(_result), do: false

  @doc """
  Checks if test output contains expected patterns.

  Validates that captured test output includes the given expected substring.
  Returns true if the pattern is found and exit code is zero, false otherwise.
  """
  @spec assert_test_output_contains({String.t(), integer(), String.t()}) :: boolean()
  def assert_test_output_contains({output, exit_code, expected}) do
    exit_code == 0 and String.contains?(to_string(output), expected)
  end

  @doc """
  Asserts that no test failures were detected.

  Combines exit code and test result validation.
  Returns true only when tests_passed > 0 and tests_failed == 0.
  """
  @spec assert_no_failures({:ok, map()} | {:error, String.t()}) :: boolean()
  def assert_no_failures({:ok, %{tests_failed: 0, tests_passed: n}}) when n > 0, do: true
  def assert_no_failures(_result), do: false
end
