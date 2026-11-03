defmodule Lux.Prisms.Languages.Rust.Types.DeserializePrism do
  @moduledoc """
  A prism for deserializing Serde payloads back into Elixir terms and structs.
  """

  use Lux.Prism,
    name: "Rust Serde Deserializer",
    description: "Deserializes Serde JSON or maps into Elixir data structures",
    input_schema: %{
      type: :object,
      properties: %{
        payload: %{
          type: [:object, :string, :array],
          description: "Serde JSON string or map to deserialize"
        }
      },
      required: ["payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deserialized: %{type: [:object, :array, :string, :number, :boolean, :null]},
        success: %{type: :boolean}
      },
      required: ["deserialized", "success"]
    }

  alias Lux.Rust.Types.Serializer

  @impl true
  def handler(inputs, _context) do
    payload = Map.get(inputs, "payload") || Map.get(inputs, :payload)

    case Serializer.deserialize(payload) do
      {:ok, deserialized} ->
        {:ok,
         %{
           deserialized: deserialized,
           success: true
         }}

      {:error, reason} ->
        {:error, "Deserialization failed: #{inspect(reason)}"}
    end
  end
end
