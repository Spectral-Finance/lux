defmodule Lux.Prisms.Languages.Rust.Types.CustomSchemaPrism do
  @moduledoc """
  A prism for generating idiomatic Rust struct and enum definitions from Elixir schema specifications.
  """

  use Lux.Prism,
    name: "Rust Schema Generator",
    description: "Generates Rust struct and enum definitions with Serde derives",
    input_schema: %{
      type: :object,
      properties: %{
        kind: %{
          type: :string,
          enum: ["struct", "enum"],
          default: "struct"
        },
        name: %{
          type: :string,
          description: "Name of the type to generate"
        },
        definition: %{
          type: [:object, :array],
          description: "Fields map for struct, or variants list for enum"
        }
      },
      required: ["name", "definition"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        rust_code: %{type: :string},
        name: %{type: :string},
        kind: %{type: :string}
      },
      required: ["rust_code", "name", "kind"]
    }

  alias Lux.Rust.Types.SchemaGenerator

  @impl true
  def handler(inputs, _context) do
    kind = Map.get(inputs, "kind") || Map.get(inputs, :kind, "struct")
    name = Map.get(inputs, "name") || Map.get(inputs, :name)
    def_data = Map.get(inputs, "definition") || Map.get(inputs, :definition)

    rust_code =
      case kind do
        "enum" ->
          SchemaGenerator.generate_enum(name, def_data)

        _ ->
          SchemaGenerator.generate_struct(name, def_data)
      end

    {:ok,
     %{
       rust_code: rust_code,
       name: name,
       kind: kind
     }}
  end
end
