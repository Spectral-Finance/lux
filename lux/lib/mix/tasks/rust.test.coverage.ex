defmodule Mix.Tasks.Rust.Test.Coverage do
  @moduledoc """
  Generates a coverage report for Rust code.

  ## Usage

      mix rust.test.coverage                     # LCov format
      mix rust.test.coverage --format html        # HTML format
      mix rust.test.coverage --output cover/rust  # Custom output dir
  """

  use Mix.Task

  @shortdoc "Generate Rust coverage report"

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        format: :string,
        output: :string,
        tool: :string
      ],
      aliases: [
        f: :format,
        o: :output
      ]
    )

    format = opts[:format] || "lcov"
    output = opts[:output] || "cover/rust"

    coverage_opts = [
      format: format,
      output_dir: output
    ]

    coverage_opts = if opts[:tool], do: Keyword.put(coverage_opts, :tool, opts[:tool]), else: coverage_opts

    Mix.shell().info("Running Rust tests with coverage instrumentation...")

    case Lux.Rust.Coverage.run_with_coverage() do
      {:ok, result} ->
        if result.failed > 0 do
          Mix.shell().error("Warning: #{result.failed} tests failed, coverage may be incomplete")
        end

        case Lux.Rust.Coverage.generate(coverage_opts) do
          {:ok, path} ->
            Mix.shell().info("Coverage report generated: #{path}")

            case Lux.Rust.Coverage.summary(coverage_dir: output) do
              {:ok, summary} ->
                Mix.shell().info("""
                ── Rust Coverage ──────────────────────

                Lines covered: #{summary.lines_covered}/#{summary.lines_total}
                Percentage:    #{summary.percentage}%
                Status:        #{summary.status}
                """)

              {:error, _} ->
                Mix.shell().info("(Coverage summary unavailable)")
            end

          {:error, reason} ->
            Mix.raise("Coverage generation failed: #{reason}")
        end

      {:error, reason} ->
        Mix.raise("Failed to run tests with coverage: #{reason}")
    end
  end
end
