defmodule Lux.Prisms.Languages.Rust.Types.EnumBridgePrism do
  @moduledoc """
  A prism for converting between Elixir tagged tuples and Rust Serde enum variants.
  """

  use Lux.Prism,
    name: "Rust Enum Bridge",
    description: "Converts Elixir tagged tuples and atoms to/from Serde enum representations",
    input_schema: %{
      type: :object,
      properties: %{
        variant: %{
          type: :string,
          description: "Variant name (e.g. 'ok', 'error', 'pending')"
        },
        payload: %{
          type: [:object, :array, :string, :number, :boolean, :null],
          description: "Optional payload associated with variant"
        }
      },
      required: ["variant"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        enum_map: %{type: :object},
        variant: %{type: :string}
      },
      required: ["enum_map", "variant"]
    }

  @impl true
  def handler(inputs, _context) do
    variant = Map.get(inputs, "variant") || Map.get(inputs, :variant)
    payload = Map.get(inputs, "payload") || Map.get(inputs, :payload)

    enum_map =
      if payload != nil do
        %{"__enum__" => variant, "payload" => payload}
      else
        %{"__enum__" => variant}
      end

    {:ok,
     %{
       enum_map: enum_map,
       variant: variant
     }}
  end
end
