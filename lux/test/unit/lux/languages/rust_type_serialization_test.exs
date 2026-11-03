defmodule Lux.Languages.RustTypeSerializationTest do
  use UnitAPICase, async: true

  alias Lux.Rust.Types.SchemaGenerator
  alias Lux.Rust.Types.Serializer

  defmodule TestUser do
    defstruct [:id, :username, :score]
  end

  describe "Serializer" do
    test "serializes and deserializes basic maps and primitives" do
      data = %{"name" => "Lux", "active" => true, "count" => 42}
      assert {:ok, json_str} = Serializer.serialize(data, format: :json)
      assert is_binary(json_str)

      assert {:ok, decoded} = Serializer.deserialize(json_str)
      assert decoded == data
    end

    test "serializes Elixir struct with __struct__ metadata" do
      user = %TestUser{id: 1, username: "alice", score: 99.5}
      assert {:ok, map_rep} = Serializer.serialize(user)
      assert map_rep["__struct__"] == "Lux.Languages.RustTypeSerializationTest.TestUser"
      assert map_rep["username"] == "alice"

      # Roundtrip
      assert {:ok, %TestUser{} = restored} = Serializer.deserialize(map_rep)
      assert restored.id == 1
      assert restored.username == "alice"
    end

    test "serializes tagged tuple into __enum__ variant" do
      enum_val = {:ok, %{"code" => 200}}
      assert {:ok, map_rep} = Serializer.serialize(enum_val)
      assert map_rep["__enum__"] == "ok"
      assert map_rep["payload"] == %{"code" => 200}

      # Roundtrip
      assert {:ok, {:ok, %{"code" => 200}}} = Serializer.deserialize(map_rep)
    end
  end

  describe "SchemaGenerator" do
    test "generates Rust struct code with Serde derive" do
      schema = %{
        "id" => "string",
        "balance" => "float",
        "is_active" => "boolean"
      }

      code = SchemaGenerator.generate_struct("Account", schema)
      assert String.contains?(code, "pub struct Account {")
      assert String.contains?(code, "pub id: String,")
      assert String.contains?(code, "pub balance: f64,")
      assert String.contains?(code, "pub is_active: bool,")
      assert String.contains?(code, "derive(Debug, Clone, Serialize, Deserialize, PartialEq)")
    end

    test "generates Rust enum code with Serde derive" do
      variants = [
        {"success", "string"},
        {"failed", "string"},
        "pending"
      ]

      code = SchemaGenerator.generate_enum("Status", variants)
      assert String.contains?(code, "pub enum Status {")
      assert String.contains?(code, "Success(String),")
      assert String.contains?(code, "Pending,")
    end
  end
end
