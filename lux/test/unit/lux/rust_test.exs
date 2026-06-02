defmodule Lux.RustTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  describe "Lux.Rust component definition" do
    test "define/3 returns error when native not loaded" do
      unless Lux.Native.loaded?() do
        assert {:error, "Rust native library not loaded"} =
                 Lux.Rust.Component.define(:prism, "test_component",
                   handler: "fn process(x) { x }")
      end
    end

    test "execute/3 returns error when native not loaded" do
      unless Lux.Native.loaded?() do
        assert {:error, "Rust native library not loaded"} =
                 Lux.Rust.Component.execute(:prism, "test_component", %{data: "test"})
      end
    end

    test "list/1 returns error when native not loaded" do
      unless Lux.Native.loaded?() do
        assert {:error, "Rust native library not loaded"} =
                 Lux.Rust.Component.list(:prism)
      end
    end
  end

  describe "Lux.Rust.Lifecycle" do
    test "valid_transition?/2 validates correct transitions" do
      assert Lux.Rust.Lifecycle.valid_transition?(:uninitialized, :initializing)
      assert Lux.Rust.Lifecycle.valid_transition?(:ready, :executing)
      assert Lux.Rust.Lifecycle.valid_transition?(:executing, :error)
      assert Lux.Rust.Lifecycle.valid_transition?(:error, :ready)
    end

    test "valid_transition?/2 rejects invalid transitions" do
      refute Lux.Rust.Lifecycle.valid_transition?(:ready, :uninitialized)
      refute Lux.Rust.Lifecycle.valid_transition?(:terminated, :executing)
      refute Lux.Rust.Lifecycle.valid_transition?(:ready, :terminated)
      refute Lux.Rust.Lifecycle.valid_transition?(:nonexistent, :ready)
    end

    test "allowed_transitions/1 returns allowed states" do
      transitions = Lux.Rust.Lifecycle.allowed_transitions(:ready)
      assert :executing in transitions
      assert :suspended in transitions
      assert :shutting_down in transitions
      refute :uninitialized in transitions
    end

    test "allowed_transitions/1 handles terminal state" do
      assert Lux.Rust.Lifecycle.allowed_transitions(:terminated) == []
    end

    test "lifecycle_definition/0 returns string-keyed map" do
      defn = Lux.Rust.Lifecycle.lifecycle_definition()
      assert is_map(defn)
      assert Map.has_key?(defn, "ready")
      assert Map.has_key?(defn, "terminated")
      assert Enum.all?(defn, fn {_, v} -> is_list(v) end)
    end
  end

  describe "Lux.Rust.Registry" do
    test "stats/0 returns a map" do
      stats = Lux.Rust.Registry.stats()
      assert is_map(stats)
    end
  end

  describe "Lux.Rust sigil" do
    test "rust_crate_path/0 returns a valid path" do
      path = Lux.Rust.rust_crate_path()
      assert is_binary(path)
      assert String.contains?(path, "priv/rust")
    end

    test "eval/2 returns error when native not loaded" do
      unless Lux.Native.loaded?() do
        assert {:error, "Rust native library not loaded"} =
                 Lux.Rust.eval("fn main(x) { x }")
      end
    end

    test "version/0 delegates to Native" do
      assert {:error, _} = Lux.Rust.version()
    end
  end

  describe "Lux.Native component NIF stubs" do
    test "rust_register_component raises when library not loaded" do
      unless Lux.Native.loaded?() do
        assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
          Lux.Native.rust_register_component("{}")
        end
      end
    end

    test "rust_execute_component raises when library not loaded" do
      unless Lux.Native.loaded?() do
        assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
          Lux.Native.rust_execute_component("prism:test", "{}")
        end
      end
    end

    test "rust_component_info raises when library not loaded" do
      unless Lux.Native.loaded?() do
        assert_raise RuntimeError, ~r/Native Rust library not loaded/, fn ->
          Lux.Native.rust_component_info()
        end
      end
    end
  end
end
