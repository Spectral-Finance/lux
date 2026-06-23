defmodule Mix.Tasks.Lux.Cargo.Setup do
  @shortdoc "Sets up Cargo/Rust toolchain for Lux"

  @moduledoc """
  Mix task that initialises the Cargo integration for Lux.

  This task:

  1. Verifies that Rust/Cargo is installed.
  2. Ensures the Lux Cargo cache directory exists.
  3. Displays version information.

  ## Usage

      mix lux.cargo.setup

  """

  use Mix.Task

  @requirements []

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Setting up Lux Cargo integration...")

    case Lux.Cargo.cargo_available?() do
      false ->
        Mix.shell().error(
          "Cargo not found in PATH. Please install Rust from https://rustup.rs"
        )

        Mix.raise("Rust/Cargo is required for Lux Rust integration")

      true ->
        {:ok, cargo_ver} = Lux.Cargo.cargo_version()
        {:ok, rustc_ver} = Lux.Cargo.rustc_version()

        Mix.shell().info("✓ Cargo found: #{cargo_ver}")
        Mix.shell().info("✓ Rustc found: #{rustc_ver}")

        {:ok, cache_dir} = Lux.Cargo.ensure_cache()
        Mix.shell().info("✓ Cache directory ready: #{cache_dir}")

        Mix.shell().info("Lux Cargo integration ready.")
    end
  end
end
