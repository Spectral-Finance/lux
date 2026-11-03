defmodule Lux.Prisms.Languages.Rust.Types.SerializePrism do
  @moduledoc """
  A prism for serializing Elixir structs and data into Serde-compatible formats.
  """

  use Lux.Prism,
    name: "Rust Serde Serializer",
    description: "Serializes Elixir structs, maps, and enums into Serde JSON or maps",
    input_schema: %{
      type: :object,
      properties: %{
        payload: %{
          type: [:object, :array, :string, :number, :boolean, :null],
          description: "Elixir data structure or struct to serialize"
        },
        format: %{
          type: :string,
          enum: ["map", "json"],
          default: "map"
        }
      },
      required: ["payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        serialized: %{type: [:object, :string, :array, :number, :boolean, :null]},
        format: %{type: :string},
        success: %{type: :boolean}
      },
      required: ["serialized", "format", "success"]
    }

  alias Lux.Rust.Types.Serializer

  @impl true
  def handler(inputs, _context) do
    payload = Map.get(inputs, "payload") || Map.get(inputs, :payload)
    format_str = Map.get(inputs, "format") || Map.get(inputs, :format, "map")
    format = if format_str == "json", do: :json, else: :map

    case Serializer.serialize(payload, format: format) do
      {:ok, serialized} ->
        {:ok,
         %{
           serialized: serialized,
           format: format_str,
           success: true
         }}

      {:error, reason} ->
        {:error, "Serialization failed: #{inspect(reason)}"}
    end
  end
end
