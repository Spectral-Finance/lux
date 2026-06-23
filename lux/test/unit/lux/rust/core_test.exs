defmodule Lux.Rust.CoreTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Core

  describe "type conversion and basic FFI" do
    test "add/2 successfully adds integers natively" do
      assert Core.add(10, 20) == 30
      assert Core.add(-5, 5) == 0
    end

    test "concat_strings/2 natively concatenates" do
      assert Core.concat_strings("hello ", "world") == "hello world"
    end
  end

  describe "error handling framework" do
    test "safe_divide/2 propagates Ok Result as unwrapped value or {:ok, val} depending on rustler" do
      # In rustler, returning `Result<T, Error>` translates to `{:ok, T}` or `{:error, reason}` automatically!
      assert Core.safe_divide(10.0, 2.0) == {:ok, 5.0}
    end

    test "safe_divide/2 propagates Err as {:error, reason}" do
      assert Core.safe_divide(10.0, 0.0) == {:error, :division_by_zero}
    end
  end

  describe "memory safe buffer processing" do
    test "reverse_bytes/1 handles binary processing safely" do
      assert Core.reverse_bytes(<<1, 2, 3, 4>>) == {:ok, <<4, 3, 2, 1>>}
    end
  end
end
