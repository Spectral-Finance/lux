defmodule Lux.Native.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Native

  describe "loaded?/0" do
    test "returns a boolean" do
      assert is_boolean(Native.loaded?())
    end

    test "returns false when native library is not compiled" do
      refute Native.loaded?()
    end
  end

  describe "version/0" do
    test "returns error when library not loaded" do
      assert {:error, "Native library not loaded"} = Native.version()
    end
  end

  describe "nif stubs" do
    test "add raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.add(1, 2)
      end
    end

    test "hash_sha256 raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.hash_sha256("hello")
      end
    end

    test "hex_encode raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.hex_encode("hello")
      end
    end

    test "json_parse raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.json_parse("{}")
      end
    end

    test "lux_type_of raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.lux_type_of("hello")
      end
    end

    test "map_merge raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.map_merge(%{a: 1}, %{b: 2})
      end
    end

    test "sort_list raises when library not loaded" do
      assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
        Native.sort_list([3, 1, 2])
      end
    end
  end
end
