defmodule Lux.Rust.CoreTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Core
  alias Lux.Rust.Core.FfiError

  describe "to_rust_primitive/2 and from_rust_primitive/1" do
    test "round-trips primitive scalars, lists, and maps" do
      input = %{
        "count" => 42,
        "ratio" => 3.1415,
        "enabled" => true,
        "label" => "lux_core",
        "items" => [1, 2, 3]
      }

      assert {:ok, descriptor} = Core.to_rust_primitive(input)
      assert {:ok, restored} = Core.from_rust_primitive(descriptor)
      assert restored == input
    end

    test "enforces max_bytes memory safety boundary" do
      large_bin = String.duplicate("a", 128)
      assert {:error, %FfiError{code: "payload_too_large"}} =
               Core.to_rust_primitive(large_bin, max_bytes: 64)
    end

    test "rejects i64 overflow" do
      too_big = 9_223_372_036_854_775_808
      assert {:error, %FfiError{code: "integer_overflow"}} = Core.to_rust_primitive(too_big)
    end
  end

  describe "dot_product/2" do
    test "computes dot product and propagates dimension_mismatch errors" do
      assert {:ok, 32.0} = Core.dot_product([1, 2, 3], [4, 5, 6])
      assert {:error, %FfiError{code: "dimension_mismatch"}} = Core.dot_product([1, 2], [1])
    end
  end
end
