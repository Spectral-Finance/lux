defmodule Lux.RustTest do
  use ExUnit.Case

  test "Rust type roundtrip conversion" do
    # Arrange
    rust_data = %{
      id: "123",
      name: "Rust Data",
      module_name: "RustModule",
      handler: {MyApp.RustHandler, :handle},
      description: "Converts Rust data to Elixir",
      examples: ["example1", "example2"],
      input_schema: %{
        type: :object,
        properties: %{
          value: %{type: :integer, description: "Rust integer"}
        }
      },
      output_schema: %{
        type: :object,
        properties: %{
          converted_value: %{type: :string, description: "Elixir string"}
        }
      }
    }

    # Act
    elixir_data = Lux.Prism.new(rust_data)

    # Assert
    assert elixir_data.id == "123"
    assert elixir_data.name == "Rust Data"
    assert elixir_data.module_name == "RustModule"
    assert elixir_data.handler == {MyApp.RustHandler, :handle}
    assert elixir_data.description == "Converts Rust data to Elixir"
    assert elixir_data.examples == ["example1", "example2"]
    assert elixir_data.input_schema == %{
      type: :object,
      properties: %{
        value: %{type: :integer, description: "Rust integer"}
      }
    }
    assert elixir_data.output_schema == %{
      type: :object,
      properties: %{
        converted_value: %{type: :string, description: "Elixir string"}
      }
    }
  end
end

def test_primitive_types_roundtrip_conversion do
  # Arrange
  rust_data = %{
    id: "123",
    name: "Rust Data",
    value: 42
  }

  # Act
  elixir_data = Lux.Prism.new(rust_data)

  # Assert
  assert elixir_data.id == "123"
  assert elixir_data.name == "Rust Data"
  assert elixir_data.value == 42
end