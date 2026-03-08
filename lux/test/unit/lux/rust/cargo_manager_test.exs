defmodule Lux.Rust.CargoManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.CargoManager

  test "generate toml" do
    {:ok, toml} = CargoManager.generate_toml(%{name: "my_crate", version: "1.0.0", dependencies: %{serde: "1.0", tokio: %{version: "1.0", features: ["full"]}}})
    assert toml =~ "my_crate"
    assert toml =~ "1.0.0"
    assert toml =~ "serde"
  end

  test "generate toml missing name" do
    assert {:error, :missing_name} = CargoManager.generate_toml(%{})
  end

  test "generate toml invalid version" do
    assert {:error, :invalid_version} = CargoManager.generate_toml(%{name: "x", version: "latest"})
  end

  test "parse toml" do
    content = """
    [package]
    name = "test"
    version = "0.1.0"

    [dependencies]
    serde = "1.0"
    """
    {:ok, parsed} = CargoManager.parse_toml(content)
    assert parsed["package"]["name"] == "test"
    assert parsed["dependencies"]["serde"] == "1.0"
  end

  test "parse invalid input" do
    assert {:error, :invalid_input} = CargoManager.parse_toml(123)
  end

  test "add dependency" do
    config = %{dependencies: %{serde: %{version: "1.0"}}}
    {:ok, updated} = CargoManager.add_dependency(config, :tokio, "1.0", %{features: ["full"]})
    assert updated.dependencies[:tokio].version == "1.0"
  end

  test "remove dependency" do
    config = %{dependencies: %{serde: "1.0", tokio: "1.0"}}
    {:ok, updated} = CargoManager.remove_dependency(config, :serde)
    refute Map.has_key?(updated.dependencies, :serde)
  end

  test "remove dependency not found" do
    config = %{dependencies: %{serde: "1.0"}}
    assert {:error, :not_found} = CargoManager.remove_dependency(config, :tokio)
  end

  test "resolve dependencies" do
    {:ok, result} = CargoManager.resolve_dependencies(%{serde: %{version: "1.0.0"}, tokio: %{version: "1.28.0"}})
    assert result.conflicts == []
    assert result.resolved[:serde].compatible
  end

  test "resolve with invalid version" do
    {:error, result} = CargoManager.resolve_dependencies(%{bad: %{version: "latest"}})
    assert :bad in result.conflicts
  end

  test "cache key" do
    {:ok, key1} = CargoManager.cache_key(%{name: "a"})
    {:ok, key2} = CargoManager.cache_key(%{name: "b"})
    assert key1 != key2
    assert String.length(key1) == 16
  end

  test "build command release" do
    {:ok, cmd} = CargoManager.build_command(profile: :release, features: ["nif"])
    assert cmd =~ "cargo build --release --features nif"
  end

  test "build command debug" do
    {:ok, cmd} = CargoManager.build_command(profile: :debug)
    refute cmd =~ "--release"
  end

  test "bump version patch" do
    {:ok, v} = CargoManager.bump_version("1.2.3", :patch)
    assert v == "1.2.4"
  end

  test "bump version minor" do
    {:ok, v} = CargoManager.bump_version("1.2.3", :minor)
    assert v == "1.3.0"
  end

  test "bump version major" do
    {:ok, v} = CargoManager.bump_version("1.2.3", :major)
    assert v == "2.0.0"
  end

  test "bump invalid version" do
    assert {:error, :invalid_version} = CargoManager.bump_version("1.2")
  end
end
