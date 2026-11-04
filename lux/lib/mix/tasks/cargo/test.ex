defmodule Mix.Tasks.Cargo.Test do
  @shortdoc "Runs Rust/Cargo tests"
  @moduledoc """
  Runs Rust tests using cargo test.

  ## Examples

      # Run all Rust tests
      mix cargo.test

  This task will use Cargo to manage dependencies and run tests.
  Make sure you have Rust and Cargo installed first.
  """

  use Mix.Task

  @requirements ["app.start"]

  defp safe_cmd(cmd, args, opts) do
    System.cmd(cmd, args, opts)
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, :not_found}
        _ -> reraise e, __STACKTRACE__
      end
  end

  @impl Mix.Task
  def run(args) do
    cargo_dir = Path.join(File.cwd!(), "priv/cargo")

    case safe_cmd("which", ["cargo"], stderr_to_stdout: true) do
      {:error, :not_found} ->
        Mix.raise("""
        Cargo not found. Please install Rust first:

            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        """)
      {_, 0} ->
        run_tests(cargo_dir, args)
      {_, _} ->
        Mix.raise("""
        Cargo not found. Please install Rust first:

            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        """)
    end
  end

  defp run_tests(cargo_dir, args) do
    cargo_args =
      case args do
        [] -> ["test"]
        args -> ["test"] ++ args
      end

    case safe_cmd("cargo", cargo_args, cd: cargo_dir, stderr_to_stdout: true, into: IO.stream()) do
      {:error, :not_found} ->
        Mix.raise("Failed to execute Cargo command")

      {_, 0} ->
        :ok

      {_, status} ->
        Mix.raise("Rust tests failed with status #{status}")
    end
  end
end