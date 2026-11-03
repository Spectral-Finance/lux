defmodule Lux.Prisms.Languages.Rust.Cargo.CachePrism do
  @moduledoc """
  A prism that queries Cargo package cache status and directories.
  """

  use Lux.Prism,
    name: "Cargo Cache Inspector",
    description: "Inspects Cargo cache directories and registry status",
    input_schema: %{
      type: :object,
      properties: %{}
    },
    output_schema: %{
      type: :object,
      properties: %{
        cargo_home: %{type: :string},
        registry_cache_exists: %{type: :boolean},
        priv_rust_path: %{type: :string}
      },
      required: ["cargo_home", "registry_cache_exists", "priv_rust_path"]
    }

  alias Lux.Rust.Cargo

  @impl true
  def handler(_inputs, _context) do
    info = Cargo.cache_info()
    {:ok, info}
  end
end
