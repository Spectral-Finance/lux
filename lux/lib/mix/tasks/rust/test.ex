defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests and optional coverage reports"
  @moduledoc """
  Runs Rust tests inside `priv/rust` using Cargo and integrates with Lux's test workflow (`Spectral-Finance/lux#102`).

  ## Examples

      # Run all Rust tests
      mix rust.test

      # Run specific Rust test filter
      mix rust.test test_prism_trait

      # Run Rust tests with coverage reporting
      mix rust.test --cov

  Make sure `cargo` (Rust toolchain) is installed on your PATH.
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
    File.mkdir_p!(rust_dir)

    case safe_cmd("which", ["cargo"], stderr_to_stdout: true) do
      {:error, :not_found} ->
        raise_cargo_not_found()

      {_, 0} ->
        run_tests(rust_dir, args)

      {_, _} ->
        raise_cargo_not_found()
    end
  end

  defp raise_cargo_not_found do
    Mix.raise("""
    Cargo not found. Please install the Rust toolchain first:

        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    """)
  end

  defp run_tests(rust_dir, args) do
    cargo_args =
      cond do
        "--cov" in args ->
          rest = Enum.reject(args, &(&1 == "--cov"))
          ["tarpaulin", "--out", "Stdout"] ++ rest

        args == [] ->
          ["test"]

        true ->
          ["test"] ++ args
      end

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
end
