defmodule Mix.Tasks.Rust.Test do
  @moduledoc """
  Runs Rust tests in the Lux framework.

  ## Usage

      mix rust.test                    # Run all Rust tests
      mix rust.test --verbose          # Show detailed test output
      mix rust.test --coverage         # Generate coverage report
      mix rust.test --filter pattern   # Run tests matching pattern
      mix rust.test --features f       # Enable specific cargo features
      mix rust.test --release          # Run tests in release mode
      mix rust.test --list             # List available tests without running

  ## Integration with mix test

  This task can be chained with regular Elixir tests:

      mix test && mix rust.test
  """

  use Mix.Task

  @shortdoc "Run Rust tests"

  @impl true
  def run(args) do
    {opts, _, invalid} = OptionParser.parse(args,
      switches: [
        verbose: :boolean,
        coverage: :boolean,
        release: :boolean,
        locked: :boolean,
        list: :boolean,
        filter: :string,
        features: :string,
        coverage_output: :string
      ],
      aliases: [
        v: :verbose,
        c: :coverage,
        r: :release,
        f: :filter
      ]
    )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    rust_dir = Path.expand("../../priv/rust", __DIR__)

    unless File.dir?(rust_dir) do
      Mix.raise("Rust project directory not found at #{rust_dir}")
    end

    unless Lux.Rust.TestRunner.cargo_available?() do
      Mix.raise("""
      Cargo not found. Install Rust from https://rustup.rs.

      Then run:
          cd priv/rust && cargo build
      """)
    end

    if opts[:list] do
      list_tests(opts)
    else
      run_tests(opts)
    end
  end

  defp list_tests(opts) do
    case Lux.Rust.TestRunner.list_tests(filter: opts[:filter]) do
      {:ok, tests} ->
        count = length(tests)
        Mix.shell().info("Rust tests found: #{count}")

        Enum.each(tests, fn test ->
          Mix.shell().info("  * #{test}")
        end)

      {:error, error} ->
        Mix.raise("Failed to list tests: #{error}")
    end
  end

  defp run_tests(opts) do
    Mix.shell().info("Running Rust tests...")

    runner_opts =
      []
      |> put_if(opts[:verbose], :verbose)
      |> put_if(opts[:filter], :filter)
      |> put_if(opts[:release], :release)
      |> put_if(opts[:locked], :locked)
      |> put_if(opts[:features], :features)

    case Lux.Rust.TestRunner.run(runner_opts) do
      {:ok, result} ->
        print_test_results(result, opts[:verbose])

        if opts[:coverage] do
          run_coverage(opts)
        end

        if result.success and result.failed == 0 do
          :ok
        else
          Mix.raise("Rust tests failed (#{result.failed} failures)")
        end

      {:error, reason, result} ->
        Mix.shell().error("Rust tests failed: #{reason}")
        if result.output != "", do: Mix.shell().error(String.slice(result.output, 0, 1000))
        Mix.raise("Rust tests failed")

      {:error, reason} ->
        Mix.raise("Failed to run Rust tests: #{reason}")
    end
  end

  defp print_test_results(result, verbose) do
    Mix.shell().info("""
    ── Rust Tests ─────────────────────────

    Passed:    #{result.passed}
    Failed:    #{result.failed}
    Ignored:   #{result.ignored}
    Total:     #{result.total}
    Duration:  #{result.duration_ms}ms
    """)

    if verbose do
      Mix.shell().info("Output:")
      Mix.shell().info(result.output)
    end
  end

  defp run_coverage(opts) do
    Mix.shell().info("\nGenerating coverage report...")

    case Lux.Rust.Coverage.generate(output_dir: opts[:coverage_output]) do
      {:ok, path} ->
        Mix.shell().info("Coverage report: #{path}")

        case Lux.Rust.Coverage.summary() do
          {:ok, summary} ->
            Mix.shell().info(
              "Coverage: #{summary.percentage}% (#{summary.lines_covered}/#{summary.lines_total} lines)"
            )

          {:error, _} ->
            :ok
        end

      {:error, reason} ->
        Mix.shell().error("Coverage failed: #{reason}")
    end
  end

  defp put_if(list, _value, _key) when is_nil(list), do: list
  defp put_if(list, value, key), do: Keyword.put(list, key, value)
end
