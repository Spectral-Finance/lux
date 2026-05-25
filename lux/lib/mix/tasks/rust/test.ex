defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests"
  @moduledoc """
  Runs the Rust test suite shipped under `priv/rust/`.

  This task is the Rust counterpart of `mix python.test`. It shells out
  to `cargo test --workspace` and forwards any additional arguments to
  Cargo, so the full range of Cargo's test selectors is available.

  ## Examples

      # Run every test in the workspace
      mix rust.test

      # Forward Cargo flags
      mix rust.test --release
      mix rust.test --workspace --no-fail-fast

      # Run a single test by path
      mix rust.test signal::tests::new_signal_has_no_metadata

      # Run a single integration suite
      mix rust.test --test smoke_test

  The task expects a Rust toolchain (Cargo) to be available on `PATH`.
  Install it with [rustup](https://rustup.rs/) or via `asdf`:

      asdf plugin add rust
      asdf install rust 1.74.0
  """

  use Mix.Task

  @requirements ["app.start"]

  @rust_dir_segment "priv/rust"

  defp safe_cmd(cmd, args, opts) do
    System.cmd(cmd, args, opts)
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, :not_found}
        _ -> reraise(e, __STACKTRACE__)
      end
  end

  @impl Mix.Task
  def run(args) do
    rust_dir = Path.join(File.cwd!(), @rust_dir_segment)

    unless File.dir?(rust_dir) do
      Mix.raise("""
      Rust workspace not found at #{rust_dir}.

      Make sure you are running this task from the lux mix project root
      and that the `priv/rust/` directory exists.
      """)
    end

    case safe_cmd("which", ["cargo"], stderr_to_stdout: true) do
      {:error, :not_found} ->
        Mix.raise(cargo_missing_message())

      {_, 0} ->
        run_tests(rust_dir, args)

      {_, _} ->
        Mix.raise(cargo_missing_message())
    end
  end

  defp run_tests(rust_dir, args) do
    cargo_args = build_cargo_args(args)

    case safe_cmd("cargo", cargo_args,
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

  # Builds the argv passed to `cargo`. When the user invokes
  # `mix rust.test`, we run `cargo test --workspace`. Any additional
  # arguments are appended verbatim, supporting both Cargo flags
  # (`--release`, `--no-fail-fast`) and test name filters
  # (`signal::tests::new_signal_has_no_metadata`).
  defp build_cargo_args([]), do: ["test", "--workspace"]
  defp build_cargo_args(extra), do: ["test", "--workspace"] ++ extra

  defp cargo_missing_message do
    """
    Cargo not found on PATH.

    The Rust test suite requires the Rust toolchain. Install it with one
    of the following:

        # Recommended: rustup
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        # Or via asdf
        asdf plugin add rust
        asdf install rust 1.74.0

    Then re-run `mix rust.test`.
    """
  end
end
