defmodule Lux.Prisms.Languages.Rust.Cargo.AddDependencyPrism do
  @moduledoc """
  A prism for adding or updating a dependency in the project's `Cargo.toml`.
  """

  use Lux.Prism,
    name: "Cargo Add Dependency",
    description: "Adds or updates a crate dependency in Cargo.toml",
    input_schema: %{
      type: :object,
      properties: %{
        crate: %{
          type: :string,
          description: "Name of the crate to add (e.g. 'tokio', 'reqwest')"
        },
        version: %{
          type: :string,
          description: "Version constraint (e.g. '1.0', '0.4.19')",
          default: "1.0"
        },
        features: %{
          type: :array,
          items: %{type: :string},
          description: "Optional list of cargo features to enable",
          default: []
        }
      },
      required: ["crate"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        crate: %{type: :string},
        version: %{type: :string},
        status: %{type: :string}
      },
      required: ["crate", "status"]
    }

  alias Lux.Rust.Cargo

  @impl true
  def handler(inputs, _context) do
    crate = Map.get(inputs, "crate") || Map.get(inputs, :crate)
    version = Map.get(inputs, "version") || Map.get(inputs, :version, "1.0")
    features = Map.get(inputs, "features") || Map.get(inputs, :features, [])

    opts = [version: version]
    opts = if features != [], do: Keyword.put(opts, :features, features), else: opts

    case Cargo.add_dependency(crate, opts) do
      :ok ->
        {:ok,
         %{
           crate: crate,
           version: version,
           status: "added"
         }}

      {:error, reason} ->
        {:error, "Failed to add crate '#{crate}': #{inspect(reason)}"}
    end
  end
end
