defmodule Lux.Rust.TypeSystemTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.TypeSystem
  alias Lux.Rust.TypeSystem.{TypeDef, EnumDef}

  describe "type mapping" do
    test "maps Rust primitive types to Elixir types" do
      assert TypeSystem.map_rust_type("i8") == {:ok, :integer}
      assert TypeSystem.map_rust_type("i32") == {:ok, :integer}
      assert TypeSystem.map_rust_type("i64") == {:ok, :integer}
      assert TypeSystem.map_rust_type("u64") == {:ok, :integer}
      assert TypeSystem.map_rust_type("f32") == {:ok, :float}
      assert TypeSystem.map_rust_type("f64") == {:ok, :float}
      assert TypeSystem.map_rust_type("bool") == {:ok, :boolean}
      assert TypeSystem.map_rust_type("String") == {:ok, :string}
      assert TypeSystem.map_rust_type("Vec") == {:ok, :list}
    end

    test "maps custom types" do
      assert TypeSystem.map_rust_type("MyCustomStruct") == {:custom, "MyCustomStruct"}
    end

    test "maps generic Vec types" do
      assert TypeSystem.map_rust_type("Vec<u64>") == {:list_type, "u64"}
    end

    test "maps Elixir values to Rust type names" do
      assert TypeSystem.to_rust_type(42) == "i64"
      assert TypeSystem.to_rust_type(3.14) == "f64"
      assert TypeSystem.to_rust_type(true) == "bool"
      assert TypeSystem.to_rust_type("hello") == "String"
      assert TypeSystem.to_rust_type(:atom) == "String"
      assert TypeSystem.to_rust_type(nil) == "Option"
    end
  end

  describe "custom type definitions" do
    test "creates a TypeDef struct" do
      typedef = TypeDef.new("User", [{"name", "String"}, {"age", "u64"}])
      assert typedef.name == "User"
      assert typedef.fields == [{"name", "String"}, {"age", "u64"}]
      assert "Serialize" in typedef.derives
    end

    test "generates a Rust struct definition" do
      typedef = TypeDef.new("User", [{"name", "String"}, {"age", "u64"}])
      result = TypeSystem.generate_struct(typedef)

      assert result =~ "#[derive(Debug, Clone, Serialize, Deserialize)]"
      assert result =~ "pub struct User"
      assert result =~ "pub name: String"
      assert result =~ "pub age: u64"
    end

    test "creates an EnumDef struct" do
      enumdef = EnumDef.new("Status", [{"Active", nil}, {"Inactive", nil}])
      assert enumdef.name == "Status"
      assert enumdef.variants == [{"Active", nil}, {"Inactive", nil}]
    end

    test "generates a Rust enum definition" do
      enumdef = EnumDef.new("Status", [{"Active", nil}, {"Inactive", ["String"]}])
      result = TypeSystem.generate_enum(enumdef)

      assert result =~ "pub enum Status"
      assert result =~ "Active,"
      assert result =~ "Inactive(String)"
    end
  end

  describe "serialization" do
    test "serializes to JSON with type annotations" do
      assert {:ok, json} = TypeSystem.serialize(42)
      assert json =~ "i64"
      assert json =~ "42"

      assert {:ok, json} = TypeSystem.serialize("hello", "json")
      assert json =~ "string"
      assert json =~ "hello"
    end

    test "serializes to binary format" do
      assert {:ok, binary} = TypeSystem.serialize(true, "binary")
      assert is_binary(binary)
      assert binary =~ "bool"
    end

    test "serializes to compact format" do
      assert {:ok, encoded} = TypeSystem.serialize(42, "compact")
      assert is_binary(encoded)
    end

    test "serializes to bincode format" do
      assert {:ok, encoded} = TypeSystem.serialize(42, "bincode")
      assert is_binary(encoded)
    end

    test "returns error for unknown target type" do
      assert TypeSystem.serialize(42, "unknown") == {:error, "Unknown target type: unknown"}
    end
  end

  describe "deserialization" do
    test "deserializes from JSON" do
      {:ok, json} = TypeSystem.serialize(%{"key" => "value"})
      assert {:ok, decoded} = TypeSystem.deserialize(json)
      assert decoded["key"] == "value"
    end

    test "round-trip JSON serialization" do
      original = %{"name" => "test", "count" => 42, "active" => true}
      {:ok, json} = TypeSystem.serialize(original)
      assert {:ok, decoded} = TypeSystem.deserialize(json, "json")
      assert decoded["name"] == "test"
      assert decoded["count"] == 42
      assert decoded["active"] == true
    end

    test "round-trip compact encoding" do
      {:ok, encoded} = TypeSystem.serialize(42, "compact")
      assert {:ok, decoded} = TypeSystem.deserialize(encoded, "compact")
      assert decoded == 42
    end

    test "round-trip compact encoding for floats" do
      {:ok, encoded} = TypeSystem.serialize(3.14, "compact")
      assert {:ok, decoded} = TypeSystem.deserialize(encoded, "compact")
      assert decoded == 3.14
    end

    test "round-trip compact encoding for strings" do
      {:ok, encoded} = TypeSystem.serialize("hello", "compact")
      assert {:ok, decoded} = TypeSystem.deserialize(encoded, "compact")
      assert decoded == "hello"
    end

    test "round-trip compact encoding for lists" do
      {:ok, encoded} = TypeSystem.serialize([1, 2, 3], "compact")
      assert {:ok, decoded} = TypeSystem.deserialize(encoded, "compact")
      assert decoded == [1, 2, 3]
    end

    test "round-trip bincode encoding" do
      {:ok, encoded} = TypeSystem.serialize(42, "bincode")
      assert {:ok, decoded} = TypeSystem.deserialize(encoded, "bincode")
      assert decoded == 42
    end
  end

  describe "bidirectional conversion" do
    test "converts Elixir values to Rust-compatible representation" do
      assert TypeSystem.elixir_to_rust_value(42) == %{__type__: "i64", __value__: 42}
      assert TypeSystem.elixir_to_rust_value(true) == %{__type__: "bool", __value__: true}
      assert TypeSystem.elixir_to_rust_value("hi") == %{__type__: "String", __value__: "hi"}
      assert TypeSystem.elixir_to_rust_value(nil) == %{__type__: "Option", __value__: nil}
    end

    test "round-trips Rust-compatible representation" do
      values = [42, 3.14, true, "hello", nil, [1, 2, 3], %{"a" => 1}]

      for val <- values do
        rust_repr = TypeSystem.elixir_to_rust_value(val)
        result = TypeSystem.rust_to_elixir_value(rust_repr)

        assert result == val,
               "Round-trip failed for #{inspect(val)}: got #{inspect(result)}"
      end
    end

    test "converts maps with mixed types" do
      input = %{"name" => "Alice", "age" => 30, "scores" => [95, 87, 92]}
      rust_repr = TypeSystem.elixir_to_rust_value(input)
      result = TypeSystem.rust_to_elixir_value(rust_repr)
      assert result == input
    end
  end

  describe "struct and enum support" do
    defmodule User do
      defstruct [:name, :age]
    end

    test "converts struct to Rust format" do
      user = %User{name: "Alice", age: 30}
      result = TypeSystem.struct_to_rust(user)

      assert result.__type__ == "Elixir.Lux.Rust.TypeSystemTest.User"
      assert Enum.find(result.__fields__, &(elem(&1, 0) == "name")) |> elem(1) |> Map.get(:__value__) == "Alice"
    end

    test "converts enum values" do
      assert {:ok, result} = TypeSystem.enum_to_rust(:active, ["ACTIVE", "INACTIVE"])
      assert result == %{__enum__: "ACTIVE"}

      assert {:ok, result} = TypeSystem.rust_to_enum(%{__enum__: "ACTIVE"})
      assert result == :active
    end
  end
end
