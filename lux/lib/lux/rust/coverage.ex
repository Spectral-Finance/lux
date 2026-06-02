defmodule Lux.Rust.Coverage do
  @moduledoc """
  Coverage reporting for Rust code in Lux.

  Generates coverage reports for Rust tests using cargo-llvm-cov or grcov,
  and provides coverage summary parsing and integration with the Lux test pipeline.
  """

  alias Lux.Rust.TestRunner

  @rust_project_path TestRunner.rust_project_path()

  @type coverage_summary :: %{
          lines_covered: non_neg_integer(),
          lines_total: non_neg_integer(),
          percentage: float(),
          status: :pass | :fail | :unknown
        }

  @doc """
  Generates a coverage report for the Rust code.

  ## Options
    * `:tool` — coverage tool to use ("cargo-llvm-cov" or "grcov", default: auto-detect)
    * `:output_dir` — output directory for reports (default: "cover/rust")
    * `:format` — report format ("lcov", "html", "json", default: "lcov")

  ## Returns
    * `{:ok, output_path}` — coverage generated successfully
    * `{:error, reason}` — coverage generation failed
  """
  @spec generate(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(opts \\ []) do
    output_dir = Keyword.get(opts, :output_dir, "cover/rust")
    format = Keyword.get(opts, :format, "lcov")
    tool = Keyword.get(opts, :tool, detect_coverage_tool())

    File.mkdir_p!(output_dir)

    case tool do
      "cargo-llvm-cov" ->
        generate_with_llvm_cov(output_dir, format)

      "grcov" ->
        generate_with_grcov(output_dir, format)

      _ ->
        {:error, "No coverage tool detected. Install cargo-llvm-cov or grcov."}
    end
  end

  @doc """
  Returns a coverage summary from existing coverage data.

  Returns a map with `:lines_covered`, `:lines_total`, `:percentage`, and `:status`.
  """
  @spec summary(keyword()) :: {:ok, coverage_summary()} | {:error, String.t()}
  def summary(opts \\ []) do
    coverage_dir = Keyword.get(opts, :coverage_dir, "cover/rust")

    lcov_path = Path.join(coverage_dir, "lcov.info")

    if File.exists?(lcov_path) do
      {:ok, parse_lcov(lcov_path)}
    else
      find_and_parse_coverage(coverage_dir)
    end
  end

  @doc """
  Checks if any coverage tool is available.
  """
  @spec coverage_available?() :: boolean()
  def coverage_available? do
    System.find_executable("cargo-llvm-cov") != nil or
      System.find_executable("grcov") != nil
  end

  @doc """
  Detects which coverage tool is available.
  Returns "cargo-llvm-cov", "grcov", or nil if none found.
  """
  @spec detect_coverage_tool() :: String.t() | nil
  def detect_coverage_tool do
    cond do
      System.find_executable("cargo-llvm-cov") != nil -> "cargo-llvm-cov"
      System.find_executable("grcov") != nil -> "grcov"
      true -> nil
    end
  end

  @doc """
  Runs tests with coverage instrumentation and returns the raw coverage data.
  """
  @spec run_with_coverage(keyword()) :: {:ok, TestRunner.test_result()} | {:error, String.t()}
  def run_with_coverage(opts \\ []) do
    TestRunner.run(Keyword.merge(opts, coverage: true))
  end

  defp generate_with_llvm_cov(output_dir, format) do
    output_file = Path.join(output_dir, "#{format}.info")

    case System.cmd("cargo", ["llvm-cov", "--#{format}", "--output-path", output_file],
           cd: @rust_project_path,
           stderr_to_stdout: true) do
      {_output, 0} -> {:ok, output_file}
      {output, code} -> {:error, "cargo-llvm-cov failed (#{code}): #{String.slice(output, 0, 300)}"}
    end
  end

  defp generate_with_grcov(output_dir, _format) do
    case System.cmd("grcov", [
           ".",
           "--binary-path", "target/debug/deps",
           "--source-dir", ".",
           "--output-types", "lcov",
           "--branch",
           "--ignore-not-existing",
           "-o", output_dir
         ],
           cd: @rust_project_path,
           stderr_to_stdout: true) do
      {_output, 0} ->
        lcov_path = Path.join(output_dir, "lcov.info")
        {:ok, lcov_path}

      {output, code} ->
        {:error, "grcov failed (#{code}): #{String.slice(output, 0, 300)}"}
    end
  end

  defp parse_lcov(path) do
    content = File.read!(path)

    lines_found =
      ~r/LF:(\d+)/
      |> Regex.scan(content)
      |> Enum.map(fn [_, n] -> String.to_integer(n) end)
      |> Enum.sum()

    lines_hit =
      ~r/LH:(\d+)/
      |> Regex.scan(content)
      |> Enum.map(fn [_, n] -> String.to_integer(n) end)
      |> Enum.sum()

    percentage = if lines_found > 0, do: Float.round(lines_hit / lines_found * 100, 2), else: 0.0

    status = cond do
      lines_found == 0 -> :unknown
      percentage >= 80.0 -> :pass
      true -> :fail
    end

    %{
      lines_covered: lines_hit,
      lines_total: lines_found,
      percentage: percentage,
      status: status
    }
  end

  defp find_and_parse_coverage(dir) do
    possible = [
      Path.join(dir, "lcov.info"),
      Path.join(dir, "coverage.info"),
      Path.join(dir, "coverage.lcov")
    ]

    found = Enum.find(possible, &File.exists?/1)

    if found do
      {:ok, parse_lcov(found)}
    else
      {:error, "No coverage data found in #{dir}"}
    end
  end
end
