defmodule Lux.Prisms.Languages.Rust.Testing.FixturePrism do
  @moduledoc """
  A prism that generates standard test datasets, vectors, and fixtures for Rust testing.
  """

  use Lux.Prism,
    name: "Rust Test Fixtures",
    description: "Generates test fixtures and vector datasets for cross-language validation",
    input_schema: %{
      type: :object,
      properties: %{
        fixture_name: %{
          type: :string,
          enum: ["vectors", "matrix", "crypto_keys", "fib_cases"],
          default: "vectors"
        },
        size: %{
          type: :integer,
          default: 10
        }
      },
      required: ["fixture_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        fixture_name: %{type: :string},
        fixture_data: %{type: [:object, :array]}
      },
      required: ["fixture_name", "fixture_data"]
    }

  @impl true
  def handler(inputs, _context) do
    name = Map.get(inputs, "fixture_name") || Map.get(inputs, :fixture_name, "vectors")
    size = Map.get(inputs, "size") || Map.get(inputs, :size, 10)

    data =
      case name do
        "vectors" ->
          %{
            "a" => Enum.map(1..size, &(&1 * 1.5)),
            "b" => Enum.map(1..size, &(&1 * 2.0))
          }

        "fib_cases" ->
          Enum.map(0..min(size, 20), fn n -> %{"n" => n} end)

        "crypto_keys" ->
          %{
            "priv_key" => "0x" <> String.duplicate("a", 64),
            "pub_key" => "0x" <> String.duplicate("b", 128)
          }

        _ ->
          %{"items" => Enum.to_list(1..size)}
      end

    {:ok,
     %{
       fixture_name: name,
       fixture_data: data
     }}
  end
end
