defmodule Lux.Rust.Testing do
  @moduledoc """
  Rust/Cargo testing integration for Lux.

  Provides structured test execution, output parsing, coverage support, and
  temporary fixture management for Rust projects — all callable from Elixir.

  ## Features

  - **Test execution**: Run `cargo test` and receive structured results
  - **Targeted tests**: Run a single test by name
  - **Coverage**: Run with `cargo llvm-cov`, falling back to plain `cargo test`
  - **Output parsing**: Convert raw cargo test stdout into a typed result map
  - **Report generation**: HTML or plain-text coverage reports
  - **Fixture management**: Create and tear down temporary Cargo projects

  ## Quick start

      # Run all tests in a project
      {:ok, result} = Lux.Rust.Testing.run_tests("/path/to/project")
      result.passed  #=> 5
      result.failed  #=> 0

      # Parse cargo output without spawning a process
      {:ok, result} = Lux.Rust.Testing.parse_test_output(output_string)

      # Temporary fixture for isolated testing
      {:ok, dir} = Lux.Rust.Testing.setup_test_fixture("my_fixture", source_code)
      Lux.Rust.Testing.cleanup_fixture(dir)

  ## Result map

  All test-running functions return a result map with the shape:

      %{
        passed:       non_neg_integer(),
        failed:       non_neg_integer(),
        ignored:      non_neg_integer(),
        output:       String.t(),
        duration_ms:  non_neg_integer(),
        coverage_pct: float() | nil
      }
  """

  require Logger

  @type path :: String.t()
  @type test_name :: String.t()

  @type result :: %{
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          ignored: non_neg_integer(),
          output: String.t(),
          duration_ms: non_neg_integer(),
          coverage_pct: float() | nil
        }

  @empty_result %{
    passed: 0,
    failed: 0,
    ignored: 0,
    output: "",
    duration_ms: 0,
    coverage_pct: nil
  }

  # ── Public API ───────────────────────────────────────────────────────────────

  @doc """
  Runs `cargo test` in `project_dir` and returns a structured result.

  ## Options

    * `:features` — list of Cargo feature strings to activate
    * `:release`  — run in release profile (default: `false`)

  ## Examples

      iex> Lux.Rust.Testing.run_tests("/path/to/project")
      {:ok, %{passed: 3, failed: 0, ignored: 0, output: "...", duration_ms: 120, coverage_pct: nil}}

      iex> Lux.Rust.Testing.run_tests("/missing")
      {:error, "cargo not found — install Rust via https://rustup.rs"}
  """
  @spec run_tests(path(), keyword()) :: {:ok, result()} | {:error, String.t()}
  def run_tests(project_dir, opts \\ []) do
    args = ["test"] ++ feature_flags(opts) ++ release_flags(opts)
    timed_cargo(project_dir, args)
  end

  @doc """
  Same as `run_tests/2` but raises `RuntimeError` on failure.
  """
  @spec run_tests!(path(), keyword()) :: result()
  def run_tests!(project_dir, opts \\ []) do
    case run_tests(project_dir, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise RuntimeError, message: reason
    end
  end

  @doc """
  Runs a single named test in `project_dir`.

  `test_name` is passed as the filter argument to `cargo test`.

  ## Examples

      iex> Lux.Rust.Testing.run_test("/path/to/project", "adds_two_numbers")
      {:ok, %{passed: 1, failed: 0, ignored: 0, output: "...", duration_ms: 45, coverage_pct: nil}}
  """
  @spec run_test(path(), test_name(), keyword()) :: {:ok, result()} | {:error, String.t()}
  def run_test(project_dir, test_name, opts \\ []) do
    args = ["test"] ++ feature_flags(opts) ++ release_flags(opts) ++ [test_name]
    timed_cargo(project_dir, args)
  end

  @doc """
  Runs tests with coverage via `cargo llvm-cov`.

  Falls back to plain `cargo test` when `cargo-llvm-cov` is not installed,
  in which case `coverage_pct` in the result will be `nil`.

  ## Options

  Same as `run_tests/2`.

  ## Examples

      iex> Lux.Rust.Testing.with_coverage("/path/to/project")
      {:ok, %{passed: 5, failed: 0, ignored: 0, output: "...", duration_ms: 300, coverage_pct: 87.5}}
  """
  @spec with_coverage(path(), keyword()) :: {:ok, result()} | {:error, String.t()}
  def with_coverage(project_dir, opts \\ []) do
    args = ["llvm-cov"] ++ feature_flags(opts) ++ release_flags(opts) ++ ["--text"]

    case timed_cargo(project_dir, args) do
      {:ok, result} ->
        coverage = extract_coverage(result.output)
        {:ok, %{result | coverage_pct: coverage}}

      {:error, _} ->
        Logger.info("cargo-llvm-cov not available, falling back to cargo test")
        run_tests(project_dir, opts)
    end
  end

  @doc """
  Parses raw `cargo test` stdout into a structured result map.

  Handles the standard cargo test result line:

      test result: ok. 5 passed; 1 failed; 2 ignored; ...

  Returns `{:error, reason}` when the output cannot be parsed.

  ## Examples

      iex> output = "test result: ok. 3 passed; 0 failed; 1 ignored; 0 measured; finished in 0.02s"
      iex> Lux.Rust.Testing.parse_test_output(output)
      {:ok, %{passed: 3, failed: 0, ignored: 1, output: ^output, duration_ms: 20, coverage_pct: nil}}
  """
  @spec parse_test_output(String.t()) :: {:ok, result()} | {:error, String.t()}
  def parse_test_output(output) when is_binary(output) do
    result_line_re = ~r/test result: (?:ok|FAILED)\. (\d+) passed; (\d+) failed; (\d+) ignored/
    duration_re = ~r/finished in ([\d.]+)s/

    case Regex.run(result_line_re, output) do
      [_, passed_s, failed_s, ignored_s] ->
        duration_ms =
          case Regex.run(duration_re, output) do
            [_, secs_s] -> round(String.to_float(secs_s) * 1000)
            _ -> 0
          end

        {:ok,
         %{
           passed: String.to_integer(passed_s),
           failed: String.to_integer(failed_s),
           ignored: String.to_integer(ignored_s),
           output: output,
           duration_ms: duration_ms,
           coverage_pct: nil
         }}

      _ ->
        if output == "" or String.trim(output) == "" do
          {:ok, @empty_result}
        else
          {:error, "Could not parse cargo test output: #{String.slice(output, 0, 200)}"}
        end
    end
  end

  @doc """
  Generates a coverage report in `output_dir`.

  Requires `cargo-llvm-cov`. Supported formats are `:html` and `:text`.
  The report is written to `output_dir` and the path is returned on success.

  ## Examples

      iex> Lux.Rust.Testing.generate_report("/path/to/project", format: :html, output_dir: "/tmp/coverage")
      {:ok, "/tmp/coverage"}
  """
  @spec generate_report(path(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_report(project_dir, opts \\ []) do
    format = Keyword.get(opts, :format, :html)
    output_dir = Keyword.get(opts, :output_dir, Path.join(project_dir, "coverage"))

    File.mkdir_p!(output_dir)

    format_flag =
      case format do
        :html -> "--html"
        :text -> "--text"
        other -> "--#{other}"
      end

    args = ["llvm-cov", format_flag, "--output-dir", output_dir]

    case run_cargo(project_dir, args) do
      {:ok, _output} -> {:ok, output_dir}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a temporary Cargo project with the given Rust source code.

  The project is created under `System.tmp_dir!/0` with name `fixture_name`.
  Returns the path to the created project directory.

  ## Examples

      iex> source = "pub fn add(a: i32, b: i32) -> i32 { a + b }"
      iex> {:ok, dir} = Lux.Rust.Testing.setup_test_fixture("my_adder", source)
      iex> File.exists?(Path.join(dir, "Cargo.toml"))
      true
  """
  @spec setup_test_fixture(String.t(), String.t()) :: {:ok, path()} | {:error, String.t()}
  def setup_test_fixture(fixture_name, source_code) do
    dir = Path.join(System.tmp_dir!(), "lux_rust_fixture_#{fixture_name}_#{rand_suffix()}")

    with :ok <- File.mkdir_p(Path.join(dir, "src")),
         :ok <- write_cargo_toml(dir, fixture_name),
         :ok <- File.write(Path.join(dir, "src/lib.rs"), source_code) do
      {:ok, dir}
    else
      {:error, reason} ->
        {:error, "Failed to create fixture at #{dir}: #{inspect(reason)}"}
    end
  end

  @doc """
  Removes a temporary fixture directory created by `setup_test_fixture/2`.

  ## Examples

      iex> Lux.Rust.Testing.cleanup_fixture("/tmp/lux_rust_fixture_my_adder_abc123")
      :ok
  """
  @spec cleanup_fixture(path()) :: :ok | {:error, String.t()}
  def cleanup_fixture(dir) do
    case File.rm_rf(dir) do
      {:ok, _} -> :ok
      {:error, reason, _path} -> {:error, "Failed to remove #{dir}: #{inspect(reason)}"}
    end
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp timed_cargo(dir, args) do
    started_at = System.monotonic_time(:millisecond)

    case run_cargo(dir, args) do
      {:ok, output} ->
        elapsed = System.monotonic_time(:millisecond) - started_at

        case parse_test_output(output) do
          {:ok, result} -> {:ok, %{result | duration_ms: elapsed, output: output}}
          {:error, _} -> {:ok, %{@empty_result | output: output, duration_ms: elapsed}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_cargo(dir, args) do
    case System.cmd("cargo", args, cd: dir, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, code} ->
        case parse_test_output(output) do
          {:ok, %{failed: n}} when n > 0 ->
            {:ok, String.trim(output)}

          _ ->
            {:error, "cargo #{hd(args)} failed (exit #{code}):\n#{output}"}
        end
    end
  rescue
    ErlangError ->
      {:error, "cargo not found — install Rust via https://rustup.rs"}
  end

  defp feature_flags(opts) do
    case Keyword.get(opts, :features, []) do
      [] -> []
      fs -> ["--features", Enum.join(fs, ",")]
    end
  end

  defp release_flags(opts) do
    if Keyword.get(opts, :release, false), do: ["--release"], else: []
  end

  defp extract_coverage(output) do
    re = ~r/(\d+(?:\.\d+)?)\s*%/

    case Regex.run(re, output) do
      [_, pct_s] ->
        case Float.parse(pct_s) do
          {pct, _} -> pct
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp write_cargo_toml(dir, name) do
    content = """
    [package]
    name = "#{name}"
    version = "0.1.0"
    edition = "2021"

    [lib]
    name = "#{String.replace(name, "-", "_")}"
    path = "src/lib.rs"
    """

    File.write(Path.join(dir, "Cargo.toml"), content)
  end

  defp rand_suffix do
    :rand.uniform(999_999_999) |> Integer.to_string()
  end
end
