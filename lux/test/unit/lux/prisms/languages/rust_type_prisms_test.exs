defmodule Lux.Prisms.Languages.RustTypePrismsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Languages.Rust.Types.CustomSchemaPrism
  alias Lux.Prisms.Languages.Rust.Types.DeserializePrism
  alias Lux.Prisms.Languages.Rust.Types.EnumBridgePrism
  alias Lux.Prisms.Languages.Rust.Types.SerializePrism
  alias Lux.Prisms.Languages.Rust.Types.ValidatePrism

  describe "SerializePrism & DeserializePrism" do
    test "serializes to JSON and deserializes back" do
      inputs = %{
        "payload" => %{"asset" => "ETH", "amount" => 5},
        "format" => "json"
      }

      assert {:ok, s_res} = SerializePrism.handler(inputs, %{})
      assert s_res.format == "json"

      assert {:ok, d_res} = DeserializePrism.handler(%{"payload" => s_res.serialized}, %{})
      assert d_res.deserialized == %{"asset" => "ETH", "amount" => 5}
    end
  end

  describe "CustomSchemaPrism" do
    test "generates struct code" do
      inputs = %{
        "kind" => "struct",
        "name" => "Trade",
        "definition" => %{"price" => "float", "size" => "float"}
      }

      assert {:ok, result} = CustomSchemaPrism.handler(inputs, %{})
      assert result.name == "Trade"
      assert String.contains?(result.rust_code, "pub struct Trade {")
    end
  end

  describe "EnumBridgePrism" do
    test "builds enum map" do
      inputs = %{
        "variant" => "rejected",
        "payload" => "slippage_too_high"
      }

      assert {:ok, result} = EnumBridgePrism.handler(inputs, %{})
      assert result.variant == "rejected"
      assert result.enum_map["__enum__"] == "rejected"
      assert result.enum_map["payload"] == "slippage_too_high"
    end
  end

  describe "ValidatePrism" do
    test "validates matching data" do
      orig = %{"a" => 1, "b" => 2}
      round = %{"a" => 1, "b" => 2}

      assert {:ok, result} = ValidatePrism.handler(%{"original" => orig, "roundtripped" => round}, %{})
      assert result.is_match == true
      assert result.status == "valid"
    end
  end
end
