defmodule Mix.Tasks.Lux.Test.Rust do
  @moduledoc """
  Runs native Rust test suite via Cargo.

  ## Examples

      $ mix lux.test.rust
      $ mix lux.test.rust --filter math
  """

  use Mix.Task

  alias Lux.Rust.Testing.Runner

  @shortdoc "Runs the native Rust tests in priv/rust"

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [filter: :string])
    filter = Keyword.get(opts, :filter)

    Mix.shell().info("==> Running native Rust tests in priv/rust...")

    case Runner.run_tests(filter: filter) do
      {:ok, report} ->
        Enum.each(report.tests, fn t ->
          status_str = if t.status == :passed, do: "ok", else: to_string(t.status)
          Mix.shell().info("  test #{t.name} ... #{status_str}")
        end)

        Mix.shell().info("""

        Test result: #{if report.success, do: "ok", else: "FAILED"}. \
        #{report.passed} passed; #{report.failed} failed; #{report.ignored} ignored.
        """)

        if not report.success do
          Mix.raise("Rust test suite failed.")
        end

      {:error, reason} ->
        Mix.raise("Failed to execute Rust tests: #{inspect(reason)}")
    end
  end
end
