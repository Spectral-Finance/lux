defmodule Lux.Rust.SerdeSchemaTest do
  use ExUnit.Case, async: false
  @moduletag :unit

  alias Lux.Rust.SerdeSchema

  describe "type_mappings/0" do
    test "returns standard mappings when library is loaded" do
      cond do
        Lux.Native.loaded?() ->
          mappings = SerdeSchema.type_mappings()
          assert is_list(mappings)
          assert length(mappings) == 9
          assert %{elixir_type: "integer", rust_type: "i64"} =
                   Enum.find(mappings, &(&1.elixir_type == "integer"))

        true ->
          assert_raise ErlangError, ~r/nif_not_loaded/, fn ->
            SerdeSchema.type_mappings()
          end
      end
    end
  end

  describe "elixir_type_to_rust/1" do
    test "maps atom types" do
      cond do
        Lux.Native.loaded?() ->
          assert SerdeSchema.elixir_type_to_rust(:integer) == "i64"
          assert SerdeSchema.elixir_type_to_rust(:binary) == "String"
          assert SerdeSchema.elixir_type_to_rust(:float) == "f64"

        true ->
          :ok
      end
    end
  end

  describe "rust_type_to_elixir/1" do
    test "maps Rust types to Elixir" do
      cond do
        Lux.Native.loaded?() ->
          assert SerdeSchema.rust_type_to_elixir("i64") == "integer"
          assert SerdeSchema.rust_type_to_elixir("String") == "string"
          assert SerdeSchema.rust_type_to_elixir("f64") == "float"

        true ->
          :ok
      end
    end
  end

  describe "compatible?/2" do
    test "detects compatible type pairs" do
      cond do
        Lux.Native.loaded?() ->
          assert SerdeSchema.compatible?("integer", "i64")
          assert SerdeSchema.compatible?("binary", "String")
          refute SerdeSchema.compatible?("float", "String")

        true ->
          :ok
      end
    end
  end

  describe "define_struct/2" do
    test "generates a Rust struct definition" do
      cond do
        Lux.Native.loaded?() ->
          {:ok, result} =
            SerdeSchema.define_struct("User", [
              %{name: "id", rust_type: "u64", is_optional: false,
                default_value: nil, validators: []},
              %{name: "name", rust_type: "String", is_optional: false,
                default_value: nil, validators: []},
              %{name: "email", rust_type: "String", is_optional: true,
                default_value: nil, validators: []}
            ])

          assert result["name"] == "User"
          assert result["rust_definition"] =~ "pub struct User"

        true ->
          :ok
      end
    end
  end

  describe "define_enum/3" do
    test "generates a Rust enum definition" do
      cond do
        Lux.Native.loaded?() ->
          {:ok, result} =
            SerdeSchema.define_enum("Status", [
              %{name: "Pending", value: 0, has_payload: false, payload_type: nil},
              %{name: "Active", value: 1, has_payload: false, payload_type: nil},
              %{name: "Failed", value: 2, has_payload: true, payload_type: "String"}
            ])

          assert result["name"] == "Status"
          assert result["rust_definition"] =~ "pub enum Status"

        true ->
          :ok
      end
    end
  end

  describe "validate_json/1" do
    test "validates valid JSON" do
      cond do
        Lux.Native.loaded?() ->
          {:ok, result} = SerdeSchema.validate_json(~s({"key": "value"}))
          assert result["valid"] == true

        true ->
          :ok
      end
    end

    test "rejects invalid JSON" do
      cond do
        Lux.Native.loaded?() ->
          {:error, _} = SerdeSchema.validate_json("{invalid}")

        true ->
          :ok
      end
    end
  end

  describe "compact_json/1" do
    test "removes whitespace from JSON" do
      cond do
        Lux.Native.loaded?() ->
          compact = SerdeSchema.compact_json(~s({"a": 1, "b":  2}))
          assert compact == ~s({"a":1,"b":2})

        true ->
          :ok
      end
    end
  end

  describe "extract_types/1" do
    test "extracts type information from JSON" do
      cond do
        Lux.Native.loaded?() ->
          {:ok, types} = SerdeSchema.extract_types(
            ~s({"name":"Alice","age":30,"active":true})
          )
          assert types["name"] == "String"
          assert types["age"] == "number"
          assert types["active"] == "bool"

        true ->
          :ok
      end
    end
  end

  describe "deep_merge_json/2" do
    test "deep merges nested JSON objects" do
      cond do
        Lux.Native.loaded?() ->
          {:ok, merged} = SerdeSchema.deep_merge_json(
            ~s({"a":1,"b":{"x":1}}),
            ~s({"b":{"y":2},"c":3})
          )
          {:ok, result} = Jason.decode(merged)
          assert result["a"] == 1
          assert result["b"]["x"] == 1
          assert result["b"]["y"] == 2
          assert result["c"] == 3

        true ->
          :ok
      end
    end
  end

  describe "type_manifest/0" do
    test "generates a complete type manifest" do
      cond do
        Lux.Native.loaded?() ->
          manifest = SerdeSchema.type_manifest()
          assert is_map(manifest)
          assert manifest["integer"] == "i64"
          assert manifest["binary"] == "String"

        true ->
          :ok
      end
    end
  end
end
