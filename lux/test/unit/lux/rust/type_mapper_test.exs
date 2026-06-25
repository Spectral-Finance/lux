defmodule Lux.Rust.TypeMapperTest do
  use ExUnit.Case, async: true
  import Lux.Rust.TypeMapper
  test "basic test" do
    assert true
  end
end

  describe "elixir_to_rust_type/1" do
    test "maps integer to i64" do
      assert elixir_to_rust_type(:integer) == {:ok, "i64"}
    end
    test "maps float to f64" do
      assert elixir_to_rust_type(:float) == {:ok, "f64"}
    end
    test "maps boolean to bool" do
      assert elixir_to_rust_type(:boolean) == {:ok, "bool"}
    end
    test "maps string to String" do
      assert elixir_to_rust_type(:string) == {:ok, "String"}
    end
    test "maps bytes to Vec<u8>" do
      assert elixir_to_rust_type(:bytes) == {:ok, "Vec<u8>"}
    end
    test "maps char to char" do
      assert elixir_to_rust_type(:char) == {:ok, "char"}
    end
    test "returns error for unknown types" do
      assert elixir_to_rust_type(:unknown) == {:error, "Unknown Elixir type: :unknown"}
    end
  end

  describe "rust_to_elixir_type/1" do
    test "maps i64 to integer" do
      assert rust_to_elixir_type("i64") == {:ok, :integer}
    end
    test "maps f64 to float" do
      assert rust_to_elixir_type("f64") == {:ok, :float}
    end
    test "maps String to string" do
      assert rust_to_elixir_type("String") == {:ok, :string}
    end
    test "maps bool to boolean" do
      assert rust_to_elixir_type("bool") == {:ok, :boolean}
    end
    test "maps Vec<u8> to bytes" do
      assert rust_to_elixir_type("Vec<u8>") == {:ok, :bytes}
    end
    test "maps HashMap to hash_map" do
      assert rust_to_elixir_type("HashMap<String, i64>") == {:ok, :hash_map}
    end
    test "returns error for unknown types" do
      assert rust_to_elixir_type("unknown") == {:error, "Unknown Rust type: unknown"}
    end
  end

  describe "container_to_rust/2" do
    test "creates Vec type" do
      assert container_to_rust(:vec, {:primitive, :integer}) == {:ok, "Vec<i64>"}
    end
    test "creates Option type" do
      assert container_to_rust(:option, {:primitive, :string}) == {:ok, "Option<String>"}
    end
    test "creates HashMap type" do
      assert container_to_rust(:hash_map, {:primitive, :string}) == {:ok, "HashMap<String, String>"}
    end
    test "returns error for unsupported container" do
      assert container_to_rust(:unsupported, {:primitive, :integer}) ==
               {:error, "Unsupported container type: :unsupported"}
    end
  end

  describe "struct_schema/2" do
    test "creates a struct schema with fields" do
      schema = struct_schema("TradeRequest", [
        {:symbol, :string, [rename: :snake_case]},
        {:amount, :float, [default: 0.0]}
      ])
      assert schema.name == "TradeRequest"
      assert length(schema.fields) == 2
      assert schema.fields |> Enum.at(0) |> Map.get(:name) == :symbol
      assert schema.fields |> Enum.at(1) |> Map.get(:name) == :amount
    end
    test "creates a struct schema with serde attributes" do
      schema = serde_struct_schema("Position", [{:side, :string, []}, {:size, :float, []}], tag: "type", content: "data")
      assert schema.name == "Position"
      assert schema.serde_attrs == %{tag: "type", content: "data"}
    end
  end

  describe "rust_definition/1 for structs" do
    test "generates valid Rust struct code" do
      schema = struct_schema("Point", [{:x, :float, []}, {:y, :float, []}])
      {:ok, code} = rust_definition(schema)
      assert code =~ "#[derive(Serialize, Deserialize, Debug)]"
      assert code =~ "pub struct Point"
      assert code =~ "pub x: f64"
      assert code =~ "pub y: f64"
    end
    test "includes serde attributes in generated code" do
      schema = serde_struct_schema("Position", [{:side, :string, []}, {:size, :float, []}], tag: "type", content: "data")
      {:ok, code} = rust_definition(schema)
      assert code =~ "#[derive(Serialize, Deserialize, Debug)]"
      assert code =~ "pub struct Position"
      assert code =~ "#[serde(tag = \"type\", content = \"data\")]"
    end
  end

  describe "enum_schema/2" do
    test "creates enum schema with unit variants" do
      schema = enum_schema("OrderSide", [:buy, :sell])
      assert schema.name == "OrderSide"
      assert length(schema.variants) == 2
    end
    test "creates enum schema with tuple variants" do
      schema = enum_schema("MarketEvent", [{:price_update, {:primitive, :float}}, :shutdown])
      assert schema.name == "MarketEvent"
      assert length(schema.variants) == 2
    end
  end

  describe "rust_definition/1 for enums" do
    test "generates valid Rust enum code" do
      schema = enum_schema("Status", [:pending, :completed, :failed])
      {:ok, code} = rust_definition(schema)
      assert code =~ "#[derive(Serialize, Deserialize, Debug)]"
      assert code =~ "pub enum Status"
      assert code =~ "Pending,"
      assert code =~ "Completed,"
      assert code =~ "Failed,"
    end
  end

  describe "encode/2" do
    test "encodes data with default values" do
      schema = struct_schema("Trade", [{:symbol, :string, []}, {:price_usd, :float, [default: 0.0]}])
      assert encode(%{symbol: "BTC/USD"}, schema) ==
               {:ok, %{"symbol" => "BTC/USD", "price_usd" => 0.0}}
    end
    test "encodes data without defaults" do
      schema = struct_schema("Simple", [{:name, :string, []}, {:value, :integer, []}])
      assert encode(%{name: "test", value: 42}, schema) ==
               {:ok, %{"name" => "test", "value" => 42}}
    end
  end

  describe "decode/2" do
    test "decodes wire format back to Elixir" do
      schema = struct_schema("Trade", [{:symbol, :string, []}, {:price_usd, :float, [default: 0.0]}])
      assert decode(%{"symbol" => "BTC/USD", "price_usd" => 50000.0}, schema) ==
               {:ok, %{symbol: "BTC/USD", price_usd: 50000.0}}
    end
  end

  describe "serialize_type/1" do
    test "serializes primitive types" do
      assert serialize_type({:primitive, :integer}) == {:ok, "i64"}
      assert serialize_type({:primitive, :float}) == {:ok, "f64"}
      assert serialize_type({:primitive, :string}) == {:ok, "String"}
    end
    test "serializes container types" do
      assert serialize_type({:container, :vec, {:primitive, :float}}) == {:ok, "Vec<f64>"}
      assert serialize_type({:container, :option, {:primitive, :string}}) == {:ok, "Option<String>"}
    end
    test "serializes struct and enum types" do
      assert serialize_type({:struct, "MyStruct", []}) == {:ok, "MyStruct"}
      assert serialize_type({:enum, "MyEnum", []}) == {:ok, "MyEnum"}
    end
  end

  describe "deserialize_type/1" do
    test "deserializes primitive types" do
      assert deserialize_type("i64") == {:ok, {:primitive, :integer}}
      assert deserialize_type("f64") == {:ok, {:primitive, :float}}
      assert deserialize_type("String") == {:ok, {:primitive, :string}}
    end
    test "deserializes container types" do
      assert deserialize_type("Vec<i64>") == {:ok, {:container, :vec, {:primitive, :integer}}}
      assert deserialize_type("Option<String>") == {:ok, {:container, :option, {:primitive, :string}}}
    end
    test "deserializes generic struct types" do
      assert deserialize_type("TradeRequest") == {:ok, {:type, "TradeRequest"}}
    end
  end

  describe "manifest/2" do
    test "generates a type manifest" do
      struct_schema = struct_schema("Trade", [{:symbol, :string, []}, {:amount, :float, []}])
      enum_schema = enum_schema("Status", [:pending, :done])
      manifest = manifest([struct_schema], [enum_schema])
      assert manifest[:version] == "1.0.0"
      assert map_size(manifest[:structs]) == 1
      assert map_size(manifest[:enums]) == 1
      assert manifest[:rust_code] =~ "pub struct Trade"
      assert manifest[:rust_code] =~ "pub enum Status"
    end
  end

  describe "SerdeField integration" do
    test "field with rename produces snake_case rust name" do
      field = Lux.Rust.SerdeField.from_descriptor({:price_usd, :float, [rename: :snake_case]})
      assert Lux.Rust.SerdeField.rust_name(field) == "price_usd"
      assert Lux.Rust.SerdeField.elixir_name(field) == :price_usd
    end
    test "field with default attr generates correct Rust code" do
      field = Lux.Rust.SerdeField.from_descriptor({:count, :integer, [default: 0]})
      rust_line = Lux.Rust.SerdeField.to_rust_field(field)
      assert rust_line =~ "#[serde(default"
      assert rust_line =~ "pub count: i64"
    end
  end
end
