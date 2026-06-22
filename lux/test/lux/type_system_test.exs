defmodule Lux.TypeSystemTest do
  use ExUnit.Case, async: true
  alias Lux.TypeSystem
  alias Lux.TypeSystem.ComplexStruct

  describe "type mapping and serialization" do
    test "serializes ComplexStruct to JSON via Serde" do
      struct_data = %ComplexStruct{
        id: 123,
        name: "Test Type",
        type_def: :Custom,
        metadata: "{\"key\":\"value\"}",
        is_active: true
      }

      json = TypeSystem.serialize_to_json(struct_data)
      assert is_binary(json)
      assert json =~ "Test Type"
      assert json =~ "Custom"
    end

    test "deserializes JSON to ComplexStruct via Serde" do
      json = ~s({"id":456,"name":"Deserialized","type_def":"Integer","metadata":"data","is_active":false})

      result = TypeSystem.deserialize_from_json(json)
      assert {:ok, struct_data} = result
      assert %ComplexStruct{} = struct_data
      assert struct_data.id == 456
      assert struct_data.name == "Deserialized"
      assert struct_data.type_def == :Integer
      assert struct_data.is_active == false
    end

    test "processes complex type in Rust and returns updated struct" do
      struct_data = %ComplexStruct{
        id: 789,
        name: "ProcessMe",
        type_def: :String,
        metadata: "none",
        is_active: false
      }

      updated = TypeSystem.process_complex_type(struct_data)
      assert updated.id == 789
      assert updated.name == "ProcessMe_processed"
      assert updated.type_def == :String
      assert updated.is_active == true
    end
  end
end
