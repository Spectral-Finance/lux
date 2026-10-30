defmodule Lux.Rust.TypeSystemTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.TypeSystem

  describe "to_rust_type/1" do
    test "maps primitive types correctly" do
      assert TypeSystem.to_rust_type(:string) == "String"
      assert TypeSystem.to_rust_type(:integer) == "i64"
      assert TypeSystem.to_rust_type(:float) == "f64"
      assert TypeSystem.to_rust_type(:boolean) == "bool"
      assert TypeSystem.to_rust_type(:binary) == "Vec<u8>"
    end

    test "maps composite and nested types" do
      assert TypeSystem.to_rust_type({:list, :string}) == "Vec<String>"
      assert TypeSystem.to_rust_type({:option, :integer}) == "Option<i64>"
      assert TypeSystem.to_rust_type({:map, :string, :float}) == "std::collections::HashMap<String, f64>"
    end

    test "maps custom module/atom types" do
      assert TypeSystem.to_rust_type(:user_profile) == "UserProfile"
    end
  end

  describe "generate_rust_struct/3" do
    test "generates serde struct with correct syntax and annotations" do
      fields = [
        {:id, :string},
        {:score, :float},
        {:tags, {:list, :string}},
        {:metadata, {:option, :map}}
      ]

      struct_code = TypeSystem.generate_rust_struct("AgentState", fields)

      assert String.contains?(struct_code, "#[derive(Serialize, Deserialize, Debug, Clone)]")
      assert String.contains?(struct_code, "pub struct AgentState {")
      assert String.contains?(struct_code, "pub id: String,")
      assert String.contains?(struct_code, "pub score: f64,")
      assert String.contains?(struct_code, "pub tags: Vec<String>,")
      assert String.contains?(struct_code, "pub metadata: Option<serde_json::Value>,")
    end
  end

  describe "generate_rust_enum/3" do
    test "generates tagged enum with unit and tuple variants" do
      variants = [
        :pending,
        {:completed, :string},
        {:failed, {:list, :string}}
      ]

      enum_code = TypeSystem.generate_rust_enum("TaskStatus", variants)

      assert String.contains?(enum_code, "#[serde(tag = \"type\", content = \"payload\")]")
      assert String.contains?(enum_code, "pub enum TaskStatus {")
      assert String.contains?(enum_code, "Pending,")
      assert String.contains?(enum_code, "Completed(String),")
      assert String.contains?(enum_code, "Failed(Vec<String>),")
    end
  end

  describe "bidirectional serialization" do
    test "encodes and decodes JSON payloads safely" do
      data = %{"name" => "lux-agent", "active" => true, "count" => 42}

      assert {:ok, json} = TypeSystem.to_rust_json(data)
      assert is_binary(json)

      assert {:ok, decoded} = TypeSystem.from_rust_json(json)
      assert decoded == data
    end
  end
end
