defmodule Mix.Tasks.Rust.Test do
  @moduledoc """
  Runs Rust tests for the Lux Rust project.

  ## Examples

      mix rust.test
      mix rust.test --project-path priv/rust
      mix rust.test --filter conversion --verbose
  """

  use Mix.Task

  @shortdoc "Run Rust tests with cargo"

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        switches: [project_path: :string, filter: :string, verbose: :boolean],
        aliases: [p: :project_path, f: :filter, v: :verbose]
      )

    case Lux.Rust.TestRunner.run(opts) do
      {:ok, result} ->
        Mix.shell().info("Rust tests passed: #{result.passed} passed, #{result.ignored} ignored")

      {:error, result} when is_map(result) ->
        Mix.shell().error(result.output)
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error(reason)
        exit({:shutdown, 1})
    end
  end
end
