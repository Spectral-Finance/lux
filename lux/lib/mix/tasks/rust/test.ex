defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests"
  @moduledoc """
  Runs Rust tests through cargo.

  ## Examples

      mix rust.test
      mix rust.test parser
      mix rust.test --project-root priv/rust --no-capture
      mix rust.test --coverage --coverage-output cover/rust
  """

  use Mix.Task

  alias Lux.Rust.TestRunner

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [
          project_root: :string,
          manifest_path: :string,
          package: :string,
          features: :string,
          jobs: :integer,
          release: :boolean,
          coverage: :boolean,
          coverage_tool: :string,
          coverage_output: :string,
          no_capture: :boolean,
          all_features: :boolean,
          no_default_features: :boolean,
          verbose: :boolean
        ],
        aliases: [p: :project_root, c: :coverage, v: :verbose]
      )

    if invalid != [] do
      Mix.raise("Invalid rust.test option(s): #{inspect(invalid)}")
    end

    project_root = Keyword.get(opts, :project_root, Lux.Rust.project_path())
    run_opts = run_opts(opts, positional)

    case TestRunner.run(project_root, run_opts) do
      {:ok, summary} ->
        if Keyword.get(opts, :verbose, false), do: Mix.shell().info(summary.output)
        Mix.shell().info(TestRunner.format_summary(summary))

      {:error, %{status: :missing_toolchain}} ->
        Mix.raise("Rust tests require cargo. Install Rust or set PATH so cargo is available.")

      {:error, %{status: :missing_manifest}} ->
        Mix.raise("Rust project not found. Expected Cargo.toml under #{project_root}.")

      {:error, summary} ->
        if Keyword.get(opts, :verbose, false), do: Mix.shell().error(summary.output)
        Mix.raise(TestRunner.format_summary(summary))
    end
  end

  defp run_opts(opts, positional) do
    filter = List.first(positional)

    []
    |> maybe_put(:manifest_path, Keyword.get(opts, :manifest_path))
    |> maybe_put(:package, Keyword.get(opts, :package))
    |> maybe_put(:features, Keyword.get(opts, :features))
    |> maybe_put(:jobs, Keyword.get(opts, :jobs))
    |> maybe_put(:filter, filter)
    |> maybe_put(:coverage_output, Keyword.get(opts, :coverage_output))
    |> maybe_put(:coverage_tool, coverage_tool(opts))
    |> Keyword.put(:coverage, Keyword.get(opts, :coverage, false))
    |> Keyword.put(:release, Keyword.get(opts, :release, false))
    |> Keyword.put(:no_capture, Keyword.get(opts, :no_capture, false))
    |> Keyword.put(:all_features, Keyword.get(opts, :all_features, false))
    |> Keyword.put(:no_default_features, Keyword.get(opts, :no_default_features, false))
  end

  defp coverage_tool(opts) do
    case Keyword.get(opts, :coverage_tool) do
      nil -> nil
      tool -> String.to_atom(String.replace(tool, "-", "_"))
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
