defmodule Lux.RustTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  describe "roundtrip/1" do
    test "round-trips a map" do
      assert {:ok, %{"key" => "value"}} = Lux.Rust.roundtrip(%{key: "value"})
    end

    test "round-trips a list" do
      assert {:ok, [1, 2, 3]} = Lux.Rust.roundtrip([1, 2, 3])
    end

    test "round-trips nested structures" do
      input = %{users: [%{name: "Alice", age: 30}]}
      assert {:ok, %{"users" => [%{"name" => "Alice", "age" => 30}]}} = Lux.Rust.roundtrip(input)
    end
  end

  describe "validate/2" do
    test "validates matching types" do
      assert :ok = Lux.Rust.validate("hello", "string")
      assert :ok = Lux.Rust.validate(42, "integer")
      assert :ok = Lux.Rust.validate(3.14, "number")
      assert :ok = Lux.Rust.validate(true, "boolean")
      assert :ok = Lux.Rust.validate(nil, "null")
      assert :ok = Lux.Rust.validate([1, 2], "array")
      assert :ok = Lux.Rust.validate(%{a: 1}, "object")
    end

    test "rejects mismatched types" do
      assert {:error, _} = Lux.Rust.validate(42, "string")
      assert {:error, _} = Lux.Rust.validate("hello", "integer")
    end
  end

  describe "sha256/1" do
    test "matches known hash" do
      assert Lux.Rust.sha256("hello") ==
        "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end

  describe "available?/0" do
    test "returns true when NIF loaded" do
      assert Lux.Rust.available?() == true
    end
  end
end
