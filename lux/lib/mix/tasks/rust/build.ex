defmodule Mix.Tasks.Rust.Build do
  @shortdoc "Builds the native Rust core (priv/rust)"
  @moduledoc """
  Compiles the Rust core crate in `priv/rust` into a release `cdylib` that
  Rustler loads into the BEAM as `Lux.Rust`.

  ## Examples

      # Build in release mode (default)
      mix rust.build

      # Build in debug mode
      mix rust.build --debug

  The compiled library is written to `priv/rust/target/release/liblux_rust.so`
  (or `.dylib` on macOS). `Lux.Rust` loads it automatically on module load via
  `:erlang.load_nif/2`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    rust_dir = Path.join(File.cwd!(), "priv/rust")

    unless File.dir?(rust_dir) do
      Mix.raise("""
      Rust core directory not found at #{rust_dir}.

      The Rust core is optional; if you do not need it, you can ignore this
      task. Otherwise, ensure the `priv/rust` directory exists in your Lux
      checkout.
      """)
    end

    profile = if "--debug" in args, do: [], else: ["--release"]
    cargo_args = ["build"] ++ profile

    Mix.shell().info("Building Rust core in #{rust_dir}...")

    case System.cmd("cargo", cargo_args, cd: rust_dir, stderr_to_stdout: true, into: IO.stream()) do
      {_, 0} ->
        Mix.shell().info("Rust core built successfully.")

      {output, status} ->
        Mix.raise("""
        Failed to build the Rust core (cargo exited with status #{status}):

        #{output}
        """)
    end
  end
end