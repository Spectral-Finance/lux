defmodule Lux.RustTypeTest do
  use UnitAPICase, async: false

  alias Lux.RustType

  # ---------------------------------------------------------------------------
  # Primitive type mapping
  # ---------------------------------------------------------------------------
  describe "primitive_types/0" do
    test "returns a map of Rust types to Elixir types" do
      types = RustType.primitive_types()
      assert is_map(types)
      assert types[:i32] == :integer
      assert types[:f64] == :float
      assert types[:bool] == :boolean
      assert types[:str] == :string
    end
  end

  describe "rust_to_elixir_type/1" do
    test "maps known Rust types" do
      assert {:ok, :integer} = RustType.rust_to_elixir_type(:i64)
      assert {:ok, :float} = RustType.rust_to_elixir_type(:f32)
      assert {:ok, :boolean} = RustType.rust_to_elixir_type(:bool)
    end

    test "returns error for unknown types" do
      assert {:error, _} = RustType.rust_to_elixir_type(:unknown_type)
    end
  end

  # ---------------------------------------------------------------------------
  # Struct and enum schemas
  # ---------------------------------------------------------------------------
  describe "struct_schema/2" do
    test "creates a struct schema tuple" do
      schema = RustType.struct_schema("Point", x: :float, y: :float)
      assert schema == {:struct, "Point", [x: :float, y: :float]}
    end
  end

  describe "enum_schema/2" do
    test "creates an enum schema tuple" do
      schema = RustType.enum_schema("Direction", [:north, :south, :east, :west])
      assert schema == {:enum, "Direction", [:north, :south, :east, :west]}
    end
  end

  # ---------------------------------------------------------------------------
  # Encoding: Elixir → Rust wire format
  # ---------------------------------------------------------------------------
  describe "encode/2 - primitives" do
    test "encodes integers" do
      assert {:ok, 42} = RustType.encode(42, :integer)
    end

    test "encodes floats" do
      assert {:ok, 3.14} = RustType.encode(3.14, :float)
    end

    test "coerces integer to float" do
      assert {:ok, 1.0} = RustType.encode(1, :float)
    end

    test "encodes booleans" do
      assert {:ok, true} = RustType.encode(true, :boolean)
      assert {:ok, false} = RustType.encode(false, :boolean)
    end

    test "encodes strings" do
      assert {:ok, "hello"} = RustType.encode("hello", :string)
    end

    test "encodes atoms as strings" do
      assert {:ok, "my_atom"} = RustType.encode(:my_atom, :atom)
    end

    test "encodes binaries as base64" do
      data = <<1, 2, 3>>
      assert {:ok, b64} = RustType.encode(data, :binary)
      assert is_binary(b64)
      assert Base.decode64!(b64) == data
    end

    test "encodes nil" do
      assert {:ok, nil} = RustType.encode(nil, :nil)
    end

    test "encodes :any passthrough" do
      assert {:ok, {:complex, :term}} = RustType.encode({:complex, :term}, :any)
    end
  end

  describe "encode/2 - collections" do
    test "encodes a list of integers" do
      assert {:ok, [1, 2, 3]} = RustType.encode([1, 2, 3], {:list, :integer})
    end

    test "encodes a list of strings" do
      assert {:ok, ["a", "b"]} = RustType.encode(["a", "b"], {:list, :string})
    end

    test "returns error for type mismatch in list" do
      assert {:error, _} = RustType.encode([1, "two"], {:list, :integer})
    end

    test "encodes a map with typed values" do
      assert {:ok, %{"x" => 1.0, "y" => 2.0}} =
               RustType.encode(%{x: 1.0, y: 2.0}, {:map, :string, :float})
    end
  end

  describe "encode/2 - struct" do
    test "encodes a struct-shaped map to string-keyed map" do
      schema = RustType.struct_schema("Point", x: :float, y: :float)
      assert {:ok, %{"x" => 1.0, "y" => 2.0}} = RustType.encode(%{x: 1.0, y: 2.0}, schema)
    end

    test "returns error when required struct field is nil" do
      schema = RustType.struct_schema("Point", x: :float)
      assert {:error, _} = RustType.encode(%{y: 2.0}, schema)
    end
  end

  describe "encode/2 - enum" do
    test "encodes a valid enum variant" do
      schema = RustType.enum_schema("Direction", [:north, :south])
      assert {:ok, "north"} = RustType.encode(:north, schema)
    end

    test "returns error for invalid variant" do
      schema = RustType.enum_schema("Direction", [:north, :south])
      assert {:error, _} = RustType.encode(:east, schema)
    end
  end

  # ---------------------------------------------------------------------------
  # Decoding: Rust wire format → Elixir
  # ---------------------------------------------------------------------------
  describe "decode/2 - primitives" do
    test "decodes integers" do
      assert {:ok, 99} = RustType.decode(99, :integer)
    end

    test "decodes floats" do
      assert {:ok, 2.5} = RustType.decode(2.5, :float)
    end

    test "decodes booleans" do
      assert {:ok, false} = RustType.decode(false, :boolean)
    end

    test "decodes strings" do
      assert {:ok, "world"} = RustType.decode("world", :string)
    end

    test "decodes string to atom" do
      assert {:ok, atom} = RustType.decode("my_atom", :atom)
      assert is_atom(atom)
    end

    test "decodes base64 binary" do
      data = <<10, 20, 30>>
      b64 = Base.encode64(data)
      assert {:ok, ^data} = RustType.decode(b64, :binary)
    end
  end

  describe "decode/2 - collections" do
    test "decodes a list of integers" do
      assert {:ok, [10, 20, 30]} = RustType.decode([10, 20, 30], {:list, :integer})
    end

    test "decodes a map with typed values" do
      assert {:ok, %{"a" => 1, "b" => 2}} =
               RustType.decode(%{"a" => 1, "b" => 2}, {:map, :string, :integer})
    end
  end

  describe "decode/2 - struct" do
    test "decodes a string-keyed map back to atom-keyed struct" do
      schema = RustType.struct_schema("Point", x: :float, y: :float)
      assert {:ok, %{x: 1.5, y: 2.5}} = RustType.decode(%{"x" => 1.5, "y" => 2.5}, schema)
    end
  end

  describe "decode/2 - enum" do
    test "decodes a string variant to atom" do
      schema = RustType.enum_schema("Direction", [:north, :south, :east, :west])
      assert {:ok, :north} = RustType.decode("north", schema)
    end

    test "returns error for unknown variant" do
      schema = RustType.enum_schema("Direction", [:north])
      assert {:error, _} = RustType.decode("unknown", schema)
    end
  end

  # ---------------------------------------------------------------------------
  # JSON round-trip
  # ---------------------------------------------------------------------------
  describe "to_json/2 and from_json/2" do
    test "serializes and deserializes a simple map" do
      data = %{"name" => "Lux", "count" => 42}
      assert {:ok, json} = RustType.to_json(data)
      assert {:ok, ^data} = RustType.from_json(json)
    end

    test "round-trips a struct type through JSON" do
      schema = RustType.struct_schema("Metric", name: :string, value: :float)
      input = %{name: "latency", value: 99.9}

      assert {:ok, json} = RustType.to_json(input, schema)
      assert {:ok, decoded} = RustType.from_json(json, schema)
      assert decoded.name == "latency"
      assert decoded.value == 99.9
    end

    test "round-trips a list of integers through JSON" do
      assert {:ok, json} = RustType.to_json([1, 2, 3], {:list, :integer})
      assert {:ok, [1, 2, 3]} = RustType.from_json(json, {:list, :integer})
    end
  end

  # ---------------------------------------------------------------------------
  # Type validation
  # ---------------------------------------------------------------------------
  describe "validate/2" do
    test "returns :ok for valid types" do
      assert :ok = RustType.validate(42, :integer)
      assert :ok = RustType.validate("hello", :string)
      assert :ok = RustType.validate(true, :boolean)
    end

    test "returns error for type mismatches" do
      assert {:error, _} = RustType.validate("not an int", :integer)
      assert {:error, _} = RustType.validate(42, :boolean)
    end
  end

  describe "valid?/2" do
    test "returns true for valid types" do
      assert RustType.valid?(3.14, :float)
      assert RustType.valid?([1, 2], {:list, :integer})
    end

    test "returns false for invalid types" do
      refute RustType.valid?("string", :integer)
    end
  end

  # ---------------------------------------------------------------------------
  # Type inference
  # ---------------------------------------------------------------------------
  describe "infer/1" do
    test "infers primitive types" do
      assert RustType.infer(42) == :integer
      assert RustType.infer(3.14) == :float
      assert RustType.infer(true) == :boolean
      assert RustType.infer("hello") == :string
      assert RustType.infer(:atom) == :atom
      assert RustType.infer(nil) == :nil
    end

    test "infers list types" do
      assert RustType.infer([1, 2, 3]) == {:list, :integer}
      assert RustType.infer([]) == {:list, :any}
    end

    test "infers map types" do
      assert RustType.infer(%{"x" => 1}) == {:map, :string, :integer}
    end
  end

  # ---------------------------------------------------------------------------
  # Custom type registry
  # ---------------------------------------------------------------------------
  describe "register_type/2 and lookup_type/1" do
    test "registers and looks up a custom type" do
      schema = RustType.struct_schema("Point", x: :float, y: :float)
      assert :ok = RustType.register_type("Point", schema)
      assert {:ok, ^schema} = RustType.lookup_type("Point")
    end

    test "returns error for unregistered types" do
      assert {:error, _} = RustType.lookup_type("UnknownType_#{System.unique_integer()}")
    end
  end
end
