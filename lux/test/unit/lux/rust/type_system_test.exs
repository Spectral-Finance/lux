defmodule Lux.Rust.TypeSystemTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.TypeSystem

  @moduletag :unit

  describe "convert/1" do
    test "converts map to LuxType" do
      assert {:ok, result} = TypeSystem.convert(%{name: "Alice", age: 30})
      assert result["type"] == "map"
      assert is_map(result["entries"])
    end

    test "converts list to LuxType" do
      assert {:ok, result} = TypeSystem.convert([1, 2, 3])
      assert result["type"] == "list"
    end

    test "converts primitives" do
      assert {:ok, %{"type" => "string"}} = TypeSystem.convert("hello")
      assert {:ok, %{"type" => "integer"}} = TypeSystem.convert(42)
      assert {:ok, %{"type" => "float"}} = TypeSystem.convert(3.14)
      assert {:ok, %{"type" => "boolean"}} = TypeSystem.convert(true)
      assert {:ok, %{"type" => "null"}} = TypeSystem.convert(nil)
    end
  end

  describe "roundtrip/1" do
    test "round-trips a map" do
      assert {:ok, %{"name" => "Alice"}} = TypeSystem.roundtrip(%{name: "Alice"})
    end

    test "round-trips nested structure" do
      input = %{users: [%{name: "Bob", score: 99}]}
      assert {:ok, %{"users" => [%{"name" => "Bob", "score" => 99}]}} = TypeSystem.roundtrip(input)
    end
  end

  describe "validate/2" do
    test "validates struct schema" do
      schema = TypeSystem.define_struct("User", %{
        "name" => "string",
        "age" => "integer"
      }, required: ["name", "age"])

      assert :ok = TypeSystem.validate(%{name: "Alice", age: 30}, schema)
    end

    test "rejects missing required fields" do
      schema = TypeSystem.define_struct("User", %{
        "name" => "string",
        "age" => "integer"
      }, required: ["name", "age"])

      assert {:error, msg} = TypeSystem.validate(%{name: "Alice"}, schema)
      assert msg =~ "Missing required field"
    end

    test "rejects wrong types" do
      schema = TypeSystem.define_struct("User", %{
        "name" => "string",
        "age" => "integer"
      }, required: ["name"])

      assert {:error, _} = TypeSystem.validate(%{name: 42}, schema)
    end

    test "validates list schema" do
      schema = TypeSystem.define_list("integer")
      assert :ok = TypeSystem.validate([1, 2, 3], schema)
    end

    test "rejects wrong list item type" do
      schema = TypeSystem.define_list("integer")
      assert {:error, _} = TypeSystem.validate([1, "two", 3], schema)
    end
  end

  describe "define_struct/3" do
    test "creates struct schema" do
      schema = TypeSystem.define_struct("Point", %{
        "x" => "float",
        "y" => "float"
      }, required: ["x", "y"], description: "A 2D point")

      assert schema["name"] == "Point"
      assert schema["type"]["kind"] == "struct"
      assert schema["required"] == ["x", "y"]
    end
  end

  describe "define_enum/2" do
    test "creates enum schema" do
      schema = TypeSystem.define_enum("Result", [
        {"ok", "string"},
        {"error", "string"}
      ])

      assert schema["name"] == "Result"
      assert schema["type"]["kind"] == "enum"
      assert length(schema["type"]["variants"]) == 2
    end

    test "supports unit variants" do
      schema = TypeSystem.define_enum("Status", [
        {"active", nil},
        {"inactive", nil}
      ])

      variants = schema["type"]["variants"]
      assert Enum.all?(variants, &(!Map.has_key?(&1, "data")))
    end
  end
end
