defmodule Lux.RustTest do
  use ExUnit.Case, async: true

  describe "available?/0" do
    test "returns boolean for Rust/Cargo availability" do
      result = Lux.Rust.available?()
      assert is_boolean(result)
    end
  end

  describe "version/0" do
    test "returns version string or nil" do
      result = Lux.Rust.version()
      assert is_nil(result) or is_binary(result)
    end
  end

  describe "create_project/1" do
    test "creates a new Cargo project" do
      if Lux.Rust.available?() do
        tmp_dir = System.tmp_dir!()
        project_path = Path.join(tmp_dir, "test_proj_#{:erlang.unique_integer([:positive])}")
        assert {:ok, ^project_path} = Lux.Rust.create_project(project_path)
        assert File.exists?(Path.join(project_path, "Cargo.toml"))
        File.rm_rf!(project_path)
      else
        assert true
      end
    end
  end

  describe "cache" do
    test "stores and retrieves cached results" do
      Lux.Rust.clear_cache()
      assert :ok = Lux.Rust.cache_result("test_key", %{value: 42})
      assert {:ok, %{value: 42}} = Lux.Rust.get_cached("test_key")
    end

    test "clears all cached results" do
      Lux.Rust.cache_result("key1", 1)
      Lux.Rust.cache_result("key2", 2)
      Lux.Rust.clear_cache()
      assert {:error, :not_found} = Lux.Rust.get_cached("key1")
      assert {:error, :not_found} = Lux.Rust.get_cached("key2")
    end
  end
end
