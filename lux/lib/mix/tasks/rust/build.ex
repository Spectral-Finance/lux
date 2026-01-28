defmodule Mix.Tasks.Rust.Build do
  @moduledoc """
  Builds the Rust NIF library for Lux.

  ## Usage

      mix rust.build

  ## Options

    * `--release` - Build in release mode (default: true)
    * `--debug` - Build in debug mode

  ## Prerequisites

  Requires Rust toolchain to be installed. Install via https://rustup.rs/
  """

  use Mix.Task

  @shortdoc "Builds the Rust NIF library"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [release: :boolean, debug: :boolean])

    rust_dir = Path.join([File.cwd!(), "priv", "rust"])

    unless File.dir?(rust_dir) do
      Mix.raise("Rust directory not found at #{rust_dir}")
    end

    # Check if cargo is available
    case System.find_executable("cargo") do
      nil ->
        Mix.raise("""
        Cargo not found. Please install Rust toolchain:

            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

        Then restart your shell and try again.
        """)

      _cargo_path ->
        :ok
    end

    build_mode = if opts[:debug], do: [], else: ["--release"]
    mode_name = if opts[:debug], do: "debug", else: "release"

    Mix.shell().info("Building Rust NIF in #{mode_name} mode...")

    case System.cmd("cargo", ["build"] ++ build_mode, cd: rust_dir, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("Rust NIF built successfully!")

      {output, code} ->
        Mix.shell().error(output)
        Mix.raise("Cargo build failed with exit code #{code}")
    end
  end
end
