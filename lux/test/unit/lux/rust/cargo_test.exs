defmodule Lux.Rust.CargoTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Cargo

  describe "generate_manifest/4" do
    test "generates standard Cargo.toml with dependencies" do
      deps = %{
        "serde" => "1.0",
        "serde_json" => "1.0"
      }

      manifest = Cargo.generate_manifest("my_lux_prism", "0.2.1", deps)

      assert String.contains?(manifest, "name = \"my_lux_prism\"")
      assert String.contains?(manifest, "version = \"0.2.1\"")
      assert String.contains?(manifest, "serde = \"1.0\"")
      assert String.contains?(manifest, "serde_json = \"1.0\"")
      assert String.contains?(manifest, "[lib]")
      assert String.contains?(manifest, "crate-type = [\"cdylib\", \"rlib\"]")
    end
  end

  describe "parse_manifest/1" do
    test "parses generated manifest into structured map" do
      toml = """
      [package]
      name = "spectral_core"
      version = "1.0.0"
      edition = "2021"

      [dependencies]
      tokio = "1.0"
      reqwest = "0.11"
      """

      assert {:ok, parsed} = Cargo.parse_manifest(toml)
      assert parsed["package"]["name"] == "spectral_core"
      assert parsed["package"]["version"] == "1.0.0"
      assert parsed["package"]["edition"] == "2021"
      assert parsed["dependencies"]["tokio"] == "1.0"
      assert parsed["dependencies"]["reqwest"] == "0.11"
    end
  end

  describe "dependency management" do
    test "adds and removes dependencies in manifest map" do
      manifest = %{
        "package" => %{"name" => "lux_test"},
        "dependencies" => %{"serde" => "1.0"}
      }

      updated = Cargo.add_dependency(manifest, "anyhow", "1.0")
      assert updated["dependencies"]["anyhow"] == "1.0"
      assert updated["dependencies"]["serde"] == "1.0"

      removed = Cargo.remove_dependency(updated, "serde")
      refute Map.has_key?(removed["dependencies"], "serde")
      assert removed["dependencies"]["anyhow"] == "1.0"
    end

    test "resolves string and map dependencies" do
      deps = %{
        "tokio" => "1.0",
        "serde" => %{version: "1.0", features: ["derive"]}
      }

      assert {:ok, resolved} = Cargo.resolve_dependencies(deps)
      assert resolved["tokio"] == %{version: "1.0"}
      assert resolved["serde"] == %{version: "1.0", features: ["derive"]}
    end
  end

  describe "caching" do
    test "cache_dir returns valid path string" do
      cache = Cargo.cache_dir()
      assert is_binary(cache)
      assert String.contains?(cache, "cargo_cache")
    end

    test "clean_cache runs safely on non-existent path" do
      temp_dir = Path.join(System.tmp_dir!(), "lux_test_dummy_dir_#{System.unique_integer()}")
      assert :ok = Cargo.clean_cache(temp_dir)
    end
  end
end
