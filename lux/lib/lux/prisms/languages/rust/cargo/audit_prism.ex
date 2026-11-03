defmodule Lux.Prisms.Languages.Rust.Cargo.AuditPrism do
  @moduledoc """
  A prism that inspects and audits dependencies declared in `Cargo.toml`.
  """

  use Lux.Prism,
    name: "Cargo Dependency Audit",
    description: "Inspects and audits declared Cargo dependencies",
    input_schema: %{
      type: :object,
      properties: %{
        path: %{
          type: :string,
          description: "Optional custom Cargo.toml path"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        dependencies_count: %{type: :integer},
        dependencies: %{type: :array},
        status: %{type: :string}
      },
      required: ["dependencies_count", "dependencies", "status"]
    }

  alias Lux.Rust.Cargo

  @impl true
  def handler(inputs, _context) do
    path = Map.get(inputs, "path") || Map.get(inputs, :path)
    opts = if path, do: [path: path], else: []

    case Cargo.list_dependencies(opts) do
      {:ok, deps} ->
        deps_data =
          Enum.map(deps, fn d ->
            %{
              name: d.name,
              version: d.version,
              features: d.features,
              optional: d.optional
            }
          end)

        {:ok,
         %{
           dependencies_count: length(deps),
           dependencies: deps_data,
           status: "audited"
         }}

      {:error, reason} ->
        {:error, "Failed to audit Cargo dependencies: #{inspect(reason)}"}
    end
  end
end
