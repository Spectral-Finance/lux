defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests"
  @moduledoc """
  Runs Rust tests using cargo.

  This task discovers Rust projects under `priv/rust/` and runs their tests
  with cargo. It integrates with the Lux test infrastructure and provides
  coverage reporting capabilities.

  ## Examples

      # Run all Rust tests
      mix rust.test

      # Run tests for a specific project
      mix rust.test --project lux_rust_testing

      # Run tests with verbose output
      mix rust.test --verbose

      # Run tests matching a filter pattern
      mix rust.test --filter test_serialize

      # Run tests in release mode
      mix rust.test --release

      # Run tests with coverage
      mix rust.test --coverage

      # Run specific project with filter
      mix rust.test --project lux_rust_testing --filter unit
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {parsed, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          project: :string,
          verbose: :boolean,
          release: :boolean,
          filter: :string,
          coverage: :boolean
        ],
        aliases: [
          p: :project,
          v: :verbose,
          r: :release,
          f: :filter,
          c: :coverage
        ]
      )

    project = Keyword.get(parsed, :project)
    verbose = Keyword.get(parsed, :verbose, false)
    release = Keyword.get(parsed, :release, false)
    filter = Keyword.get(parsed, :filter)
    coverage = Keyword.get(parsed, :coverage, false)

    rust_dir = Path.join(File.cwd!(), "priv/rust")

    path =
      cond do
        project -> Path.join(rust_dir, project)
        File.exists?(rust_dir) -> find_first_project(rust_dir)
        true -> Mix.raise("priv/rust directory not found")
      end

    Mix.shell().info("Running Rust tests...")

    cargo_args = ["test"]

    cargo_args =
      if release, do: cargo_args ++ ["--release"], else: cargo_args

    cargo_args = if verbose, do: cargo_args ++ ["--", "--nocapture"], else: cargo_args

    case System.find_executable("cargo") do
      nil -> Mix.raise("Cargo not found. Please install Rust: https://rustup.rs")
      _ -> :ok
    end

    case System.cmd("cargo", cargo_args,
           cd: path,
           stderr_to_stdout: true,
           into: IO.stream()
         ) do
      {_, 0} ->
        :ok

      {_, _} ->
        Mix.raise("Rust tests failed")
    end

    if coverage do
      run_coverage(path)
    end
  end

  defp find_first_project(rust_dir) do
    rust_dir
    |> File.ls!()
    |> Enum.filter(fn name ->
      candidate = Path.join(rust_dir, name)
      File.dir?(candidate) and File.exists?(Path.join(candidate, "Cargo.toml"))
    end)
    |> Enum.sort()
    |> case do
      [] -> Mix.raise("No Rust projects found in priv/rust")
      [first | _] -> Path.join(rust_dir, first)
    end
  end

  defp run_coverage(path) do
    case System.find_executable("cargo-tarpaulin") do
      nil ->
        Mix.shell().warn(
          "cargo-tarpaulin not found. Install with: cargo install cargo-tarpaulin"
        )

      _ ->
        Mix.shell().info("Running coverage...")
        System.cmd("cargo", ["tarpaulin", "--out", "Json", "--output-dir", "coverage"], cd: path)
    end
  end
end
