defmodule Lux.Rust.TypesTest do
  use UnitCase, async: true

  alias Lux.Rust.Types

  doctest Lux.Rust
  doctest Lux.Rust.Types

  describe "type mapping" do
    test "maps primitive and container specifications to Rust types" do
      assert Types.rust_type(:bool) == {:ok, "bool"}
      assert Types.rust_type(:u64) == {:ok, "u64"}
      assert Types.rust_type(:string) == {:ok, "String"}
      assert Types.rust_type({:option, :string}) == {:ok, "Option<String>"}
      assert Types.rust_type({:vec, {:option, :i32}}) == {:ok, "Vec<Option<i32>>"}
      assert Types.rust_type({:map, :string, {:vec, :i32}}) == {:ok, "HashMap<String, Vec<i32>>"}
      assert Types.rust_type({:tuple, [:i64, :string]}) == {:ok, "(i64, String)"}
    end

    test "rejects unsupported specifications" do
      assert Types.rust_type({:unknown, :thing}) ==
               {:error, {:unsupported_type, {:unknown, :thing}}}
    end

    test "infers a Rust type from a runtime value" do
      assert Types.infer_type(1) == {:ok, "i64"}
      assert Types.infer_type(1.5) == {:ok, "f64"}
      assert Types.infer_type(true) == {:ok, "bool"}
      assert Types.infer_type("x") == {:ok, "String"}
      assert Types.infer_type([1, 2, 3]) == {:ok, "Vec<i64>"}
      assert Types.infer_type(%{"a" => 1}) == {:ok, "HashMap<String, i64>"}
    end

    test "infers types for empty containers" do
      assert Types.infer_type([]) == {:ok, "Vec<()>"}
      assert Types.infer_type(%{}) == {:ok, "HashMap<String, ()>"}
      assert Types.infer_type(nil) == {:ok, "()"}
    end
  end

  describe "custom type definitions" do
    test "defines structs, enums and aliases" do
      assert %Types.Type{kind: :struct, name: "Point"} =
               Types.define("Point", {:struct, [x: :f64, y: :f64]})

      assert %Types.Type{kind: :enum, name: "Color"} =
               Types.define("Color", {:enum, [red: :unit]})

      assert %Types.Type{kind: :alias, name: "UserId"} = Types.define("UserId", :u64)
    end

    test "accepts metadata" do
      type = Types.define("Tag", {:struct, [value: :string]}, doc: "A tag", derives: ["Clone"])
      assert type.doc == "A tag"
      assert type.derives == ["Clone"]
    end

    test "uses a named type for encoding and decoding" do
      point = Types.define("Point", {:struct, [x: :f64, y: :f64]})

      assert Types.encode(%{x: 1.0, y: 2.0}, point) == {:ok, %{"x" => 1.0, "y" => 2.0}}
      assert Types.decode(%{"x" => 1.0, "y" => 2.0}, point) == {:ok, %{x: 1.0, y: 2.0}}
      assert Types.round_trip(%{x: 1.0, y: 2.0}, point) == {:ok, %{x: 1.0, y: 2.0}}
    end

    test "uses a named enum for encoding and decoding" do
      color = Types.define("Color", {:enum, [red: :unit, custom: {:tuple, [:u8, :u8, :u8]}]})

      assert Types.encode(:red, color) == {:ok, "Red"}
      assert Types.encode({:custom, {1, 2, 3}}, color) == {:ok, %{"Custom" => [1, 2, 3]}}
      assert Types.decode("Red", color) == {:ok, :red}
      assert Types.decode(%{"Custom" => [1, 2, 3]}, color) == {:ok, {:custom, {1, 2, 3}}}
    end

    test "aliases resolve to their underlying type" do
      user_id = Types.define("UserId", :u64)

      assert Types.rust_type(user_id) == {:ok, "u64"}
      assert Types.encode(1, user_id) == {:ok, 1}
      assert Types.generate(user_id) == {:error, {:not_generatable, "UserId"}}
    end

    test "JSON helpers honor named types" do
      point = Types.define("Point", {:struct, [x: :f64, y: :f64]})

      assert {:ok, json} = Types.to_json(%{x: 1.0, y: 2.0}, point)
      assert Types.from_json(json, point) == {:ok, %{x: 1.0, y: 2.0}}
    end
  end

  describe "code generation" do
    test "generates structs from a specification" do
      assert {:ok, code} = Types.generate({:struct, [id: :u64]}, name: "Item")
      assert code == "#[derive(Serialize, Deserialize)]\npub struct Item {\n    pub id: u64,\n}"
    end

    test "generates enums from a definition" do
      color = Types.define("Color", {:enum, [red: :unit, green: :unit]})
      assert {:ok, code} = Types.generate(color)

      assert code ==
               "#[derive(Serialize, Deserialize)]\npub enum Color {\n    Red,\n    Green,\n}"
    end

    test "propagates metadata into generated code" do
      type = Types.define("Tag", {:struct, [value: :string]}, tag: :internal, derives: ["Clone"])

      assert {:ok, code} = Types.generate(type)
      assert code =~ "#[derive(Serialize, Deserialize, Clone)]"
      assert code =~ "#[serde(tag = \"type\")]"
    end
  end
end
