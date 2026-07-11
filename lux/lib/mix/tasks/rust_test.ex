defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests via cargo test"
  @moduledoc """
  Runs Rust tests via `cargo test` and reports results.

  This task integrates with the Lux Rust test runner module and
  provides a CLI entry point for bounty #102.

  ## Usage

      mix rust.test
      mix rust.test Lux.Rust.TypeMappingTest

  ## Exit Codes

  - `0` — all Rust tests passed
  - `1` — one or more Rust tests failed, or cargo/tarpaulin not available

  ## Example

      $ mix rust.test
      Running Rust tests via cargo test...

      Rust Test Results:
        Passed:  42
        Failed:  0
        Total:   42
        Duration: 0.12s

      All Rust tests passed.
  """

  use Mix.Task

  require Logger

  @impl Mix.Task
  def run(args \\ []) do
    Mix.shell().info("Running Rust tests via cargo test...")

    case Lux.RustTestRunner.run(args) do
      {:ok, results} ->
        summary = Lux.RustTestRunner.summary(results)
        Mix.shell().info("""

Rust Test Results:
          Passed:  #{summary.passed}
          Failed:  #{summary.failed}
          Total:   #{summary.total}
          Duration: #{summary.duration}
        """)

        if summary.failed > 0 do
          Mix.shell().error("Some Rust tests failed.")
          exit({:shutdown, 1})
        else
          if summary.total == 0 do
            Mix.shell().error("No Rust tests were found or executed.")
            exit({:shutdown, 1})
          else
            Mix.shell().info("All Rust tests passed.")
            :ok
          end
        end

      {:error, reason} ->
        Mix.shell().error("Rust test runner failed: #{reason}")
        exit({:shutdown, 1})
    end
  end
end
