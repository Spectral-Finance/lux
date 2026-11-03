defmodule Lux.Languages.CargoTest do
  use UnitAPICase, async: true

  alias Lux.Rust.Cargo
  alias Lux.Rust.Cargo.TomlManager

  describe "TomlManager" do
    test "parses raw Cargo.toml content" do
      sample = """
      [package]
      name = "test_pkg"
      version = "0.1.0"

      [dependencies]
      serde = "1.0"
      tokio = { version = "1.0", features = ["full"] }
      """

      assert {:ok, parsed} = TomlManager.parse_string(sample)
      assert parsed["package"]["name"] == "test_pkg"
      assert parsed["dependencies"]["serde"] == "1.0"
      assert parsed["dependencies"]["tokio"]["version"] == "1.0"
    end

    test "adds and removes dependencies in TOML content" do
      content = """
      [package]
      name = "demo"

      [dependencies]
      serde = "1.0"
      """

      updated = TomlManager.add_dependency_to_content(content, "sha2", "0.10")
      assert String.contains?(updated, ~s(sha2 = "0.10"))

      removed = TomlManager.remove_dependency_from_content(updated, "sha2")
      refute String.contains?(removed, "sha2")
    end
  end

  describe "Lux.Rust.Cargo" do
    test "lists dependencies from default priv/rust/Cargo.toml" do
      assert {:ok, deps} = Cargo.list_dependencies()
      assert is_list(deps)
      names = Enum.map(deps, & &1.name)
      assert "serde" in names
      assert "serde_json" in names
    end

    test "returns cache info" do
      info = Cargo.cache_info()
      assert is_binary(info.cargo_home)
      assert is_binary(info.priv_rust_path)
    end

    test "runs cargo build or returns simulated fallback" do
      assert {:ok, res} = Cargo.build(release: true)
      assert res.compiled == true
    end
  end
end
