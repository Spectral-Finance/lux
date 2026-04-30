defmodule Mix.Tasks.Rust.Build do
  @shortdoc "Builds the Rust core module"
  @moduledoc """
  Builds the Rust core module using maturin.

  ## Examples

      # Build in development mode
      mix rust.build

      # Build in release mode
      mix rust.build --release

      # Build and install
      mix rust.build --install

  The task will use maturin to build the Rust extension module.
  Make sure you have maturin installed:

      pip install maturin
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    rust_dir = Path.join(File.cwd!(), "priv/rust/lux_core")

    unless File.dir?(rust_dir) do
      Mix.raise("Rust core directory not found at #{rust_dir}")
    end

    # Check if maturin is installed
    case System.cmd("which", ["maturin"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        Mix.shell().info("""
        maturin not found. Installing...

        Run: pip install maturin
        """)

        case System.cmd("pip", ["install", "maturin"], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {output, _} -> Mix.raise("Failed to install maturin: #{output}")
        end
    end

    # Determine build mode
    {mode, extra_args} =
      if "--release" in args do
        {"release", ["--release"]}
      else
        {"dev", []}
      end

    install? = "--install" in args

    Mix.shell().info("Building lux_core Rust module (#{mode} mode)...")

    if install? do
      # Build and install with maturin develop
      case System.cmd("maturin", ["develop"] ++ extra_args,
             cd: rust_dir,
             stderr_to_stdout: true,
             into: IO.stream()
           ) do
        {_, 0} ->
          Mix.shell().info("Rust module built and installed successfully!")

        {output, status} ->
          Mix.raise("Failed to build Rust module (exit code #{status}): #{output}")
      end
    else
      # Just build
      case System.cmd("maturin", ["build"] ++ extra_args,
             cd: rust_dir,
             stderr_to_stdout: true,
             into: IO.stream()
           ) do
        {_, 0} ->
          Mix.shell().info("Rust module built successfully!")

        {output, status} ->
          Mix.raise("Failed to build Rust module (exit code #{status}): #{output}")
      end
    end
  end
end
