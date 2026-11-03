defmodule Lux.Prisms.Languages.Rust.TypeBridgePrism do
  @moduledoc """
  A prism for converting and validating complex data types across the Elixir/Rust boundary.
  """

  use Lux.Prism,
    name: "Rust Type Bridge",
    description: "Converts and validates types between Elixir terms and Rust representation",
    input_schema: %{
      type: :object,
      properties: %{
        payload: %{
          type: [:object, :array, :string, :number, :boolean, :null],
          description: "Data structure to convert"
        }
      },
      required: ["payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        compatible_payload: %{type: [:object, :array, :string, :number, :boolean, :null]},
        detected_type: %{type: :string},
        valid: %{type: :boolean}
      },
      required: ["compatible_payload", "detected_type", "valid"]
    }

  alias Lux.Rust.Types

  @impl true
  def handler(inputs, _context) do
    payload = Map.get(inputs, "payload") || Map.get(inputs, :payload)

    type_name =
      cond do
        is_nil(payload) -> "nil"
        is_boolean(payload) -> "boolean"
        is_integer(payload) -> "integer"
        is_float(payload) -> "float"
        is_binary(payload) -> "string"
        is_map(payload) -> "map"
        is_list(payload) -> "list"
        true -> "other"
      end

    compatible = Types.to_rust_compatible(payload)

    {:ok,
     %{
       compatible_payload: compatible,
       detected_type: type_name,
       valid: true
     }}
  end
end
