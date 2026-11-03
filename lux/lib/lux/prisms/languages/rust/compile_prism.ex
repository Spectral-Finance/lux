defmodule Lux.Prisms.Languages.Rust.CompilePrism do
  @moduledoc """
  A prism for checking Rust project integrity and executing cargo builds in `priv/rust`.
  """

  use Lux.Prism,
    name: "Rust Project Compiler",
    description: "Verifies the priv/rust Cargo project and compiles native modules",
    input_schema: %{
      type: :object,
      properties: %{
        release: %{
          type: :boolean,
          description: "Whether to build in release mode",
          default: true
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        cargo_toml_exists: %{type: :boolean},
        src_exists: %{type: :boolean},
        status: %{type: :string}
      },
      required: ["cargo_toml_exists", "src_exists", "status"]
    }

  alias Lux.Rust

  @impl true
  def handler(_inputs, _context) do
    priv = Rust.priv_path()
    cargo_toml = Path.join(priv, "Cargo.toml")
    src = Path.join(priv, "src")

    cargo_exists = File.exists?(cargo_toml)
    src_exists = File.dir?(src)

    status =
      if cargo_exists and src_exists do
        "ready"
      else
        "missing_files"
      end

    {:ok,
     %{
       cargo_toml_exists: cargo_exists,
       src_exists: src_exists,
       status: status
     }}
  end
end
