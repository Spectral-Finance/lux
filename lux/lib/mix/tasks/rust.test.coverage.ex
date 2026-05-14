defmodule Mix.Tasks.Rust.Test.Coverage do
  @moduledoc """
  Prints the grcov command plan for Rust coverage.

  The task keeps coverage setup explicit because grcov may not be installed on
  every developer machine or CI image.
  """

  use Mix.Task

  @shortdoc "Show Rust coverage command plan"

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        switches: [project_path: :string, output: :string, format: :string],
        aliases: [p: :project_path, o: :output, f: :format]
      )

    plan = Lux.Rust.TestRunner.coverage_plan(opts)

    Mix.shell().info("Project: #{plan.project_path}")
    Mix.shell().info("Environment:")
    Enum.each(plan.env, fn {key, value} -> Mix.shell().info("  #{key}=#{value}") end)
    Mix.shell().info("Command:")
    Mix.shell().info("  #{Enum.join(plan.command, " ")}")
  end
end
