defmodule Lux.NativeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  describe "json_roundtrip/1" do
    test "round-trips valid JSON object" do
      input = ~s({"key":"value","num":42})
      result = Lux.Native.json_roundtrip(input)
      assert is_binary(result)
      assert Jason.decode!(result) == %{"key" => "value", "num" => 42}
    end

    test "round-trips JSON array" do
      result = Lux.Native.json_roundtrip("[1,2,3]")
      assert Jason.decode!(result) == [1, 2, 3]
    end

    test "round-trips primitives" do
      assert Lux.Native.json_roundtrip("null") == "null"
      assert Lux.Native.json_roundtrip("true") == "true"
      assert Lux.Native.json_roundtrip("42") == "42"
      assert Lux.Native.json_roundtrip(~s("hello")) == ~s("hello")
    end

    test "rejects invalid JSON" do
      assert {:error, msg} = Lux.Native.json_roundtrip("not json")
      assert msg =~ "parse error"
    end
  end

  describe "validate_json/2" do
    test "validates string type" do
      assert {:ok, "valid"} = Lux.Native.validate_json(~s("hello"), "string")
    end

    test "validates integer type" do
      assert {:ok, "valid"} = Lux.Native.validate_json("42", "integer")
    end

    test "validates float/number type" do
      assert {:ok, "valid"} = Lux.Native.validate_json("3.14", "number")
      assert {:ok, "valid"} = Lux.Native.validate_json("3.14", "float")
    end

    test "validates boolean type" do
      assert {:ok, "valid"} = Lux.Native.validate_json("true", "boolean")
    end

    test "validates null type" do
      assert {:ok, "valid"} = Lux.Native.validate_json("null", "null")
    end

    test "validates array type" do
      assert {:ok, "valid"} = Lux.Native.validate_json("[1,2]", "array")
    end

    test "validates object type" do
      assert {:ok, "valid"} = Lux.Native.validate_json(~s({"a":1}), "object")
    end

    test "validates any type" do
      assert {:ok, "valid"} = Lux.Native.validate_json("42", "any")
      assert {:ok, "valid"} = Lux.Native.validate_json(~s("str"), "any")
    end

    test "rejects type mismatch" do
      assert {:error, msg} = Lux.Native.validate_json("42", "string")
      assert msg =~ "expected string"
    end

    test "rejects unknown type" do
      assert {:error, msg} = Lux.Native.validate_json("42", "foobar")
      assert msg =~ "Unknown type"
    end
  end

  describe "sha256_hex/1" do
    test "computes correct SHA-256" do
      # Known test vector
      assert Lux.Native.sha256_hex("hello") ==
        "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end

    test "empty string" do
      assert Lux.Native.sha256_hex("") ==
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
  end

  describe "bench_json_roundtrip/2" do
    test "returns elapsed microseconds" do
      result = Lux.Native.bench_json_roundtrip(~s({"key":"value"}), 100)
      assert is_integer(result)
      assert result >= 0
    end
  end
end
