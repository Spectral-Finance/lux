defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests"
  @moduledoc """
  Runs Rust tests using Cargo.

  ## Examples

      # Run all Rust tests
      mix rust.test

      # Run specific test
      mix rust.test --test tests::integration_test

      # Show test coverage
      mix rust.test -- --nocapture

  The task will use Cargo to manage and run tests.
  Make sure you have Rust installed and have run `cargo build`
  in the priv/rust directory first.
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
    rust_dir = Path.join(File.cwd!(), "priv/rust")

    # Check if Cargo is installed
    case safe_cmd("which", ["cargo"], stderr_to_stdout: true) do
      {:error, :not_found} ->
        Mix.raise("""
        Cargo (Rust) not found. Please install Rust first:

            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        Then run `source $HOME/.cargo/env` and retry.
        """)

      {_, 0} ->
        run_tests(rust_dir, args)

      {_, _} ->
        Mix.raise("""
        Cargo (Rust) not found. Please install Rust first:

            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        Then run `source $HOME/.cargo/env` and retry.
        """)
    end
  end

  defp run_tests(rust_dir, args) do
    # Build first to catch compilation errors
    case safe_cmd("cargo", ["build"], cd: rust_dir, stderr_to_stdout: true) do
      {:error, :not_found} ->
        Mix.raise("Failed to execute Cargo command")

      {output, 0} ->
        Mix.shell().debug(output)

      {output, _} ->
        Mix.raise("Failed to build Rust project:\n\n#{output}")
    end

    # Build the cargo test command with any additional arguments
    test_args =
      case args do
        [] -> ["test"]
        args -> ["test" | args]
      end

    # Run the tests
    case safe_cmd("cargo", test_args,
           cd: rust_dir,
           stderr_to_stdout: true,
           into: IO.stream()
         ) do
      {:error, :not_found} ->
        Mix.raise("Failed to execute Cargo command")

      {_, 0} ->
        :ok

      {_, status} ->
        Mix.raise("Rust tests failed with status #{status}")
    end
  end
end
