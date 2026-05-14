defmodule Lux.Rust.CargoTest do
  use UnitCase, async: true

  alias Lux.Rust.Cargo

  test "creates and renders a Cargo manifest" do
    manifest =
      Cargo.new_manifest(
        package: %{name: "lux_native", version: "0.2.0", edition: "2021"},
        dependencies: %{
          serde: [version: "1", features: ["derive"]],
          serde_json: "1",
          local_helper: [path: "../local_helper", optional: true]
        },
        dev_dependencies: %{proptest: "1"},
        features: %{default: ["serde/derive"], native: ["local_helper"]}
      )

    toml = Cargo.to_toml(manifest)

    assert toml =~ "[package]"
    assert toml =~ ~s(name = "lux_native")
    assert toml =~ ~s(serde_json = "1")
    assert toml =~ ~s(serde = { features = ["derive"], version = "1" })
    assert toml =~ ~s(local_helper = { optional = true, path = "../local_helper" })
    assert toml =~ "[dev-dependencies]"
    assert toml =~ ~s(default = ["serde/derive"])
  end

  test "parses rendered manifests back to normalized dependency maps" do
    manifest =
      Cargo.new_manifest(
        package: %{name: "lux_native"},
        dependencies: %{
          serde: [version: "1", features: ["derive", "std"], default_features: false],
          rustler: [git: "https://github.com/rusterlium/rustler", tag: "v0.36.2"]
        }
      )

    parsed = manifest |> Cargo.to_toml() |> Cargo.parse_toml()

    assert parsed.package["name"] == "lux_native"
    assert parsed.dependencies["serde"].version == "1"
    assert parsed.dependencies["serde"].features == ["derive", "std"]
    assert parsed.dependencies["serde"].default_features == false
    assert parsed.dependencies["rustler"].git == "https://github.com/rusterlium/rustler"
    assert parsed.dependencies["rustler"].tag == "v0.36.2"
  end

  test "adds dependencies and creates stable cache keys" do
    manifest =
      Cargo.new_manifest(package: %{name: "lux_native"})
      |> Cargo.add_dependency(:serde, version: "1", features: ["derive"])
      |> Cargo.add_dependency(:serde_json, "1")

    cache_key = Cargo.cache_key(manifest)

    assert manifest.dependencies["serde"].features == ["derive"]
    assert manifest.dependencies["serde_json"].version == "1"
    assert byte_size(cache_key) == 64
    assert Cargo.cache_dir("priv/rust", manifest) == "priv/rust/.cargo-cache/#{cache_key}"
  end

  test "plans cargo commands with locked release and feature flags" do
    plan = Cargo.command_plan("priv/rust", :build, profile: :release, features: ["nif", "serde"])

    assert plan.cd =~ "priv/rust"
    assert plan.command == ["cargo", "build", "--locked", "--release", "--features", "nif,serde"]
    assert plan.env == []
  end

  test "ensures a minimal Cargo project without overwriting existing files" do
    project_path =
      Path.join(System.tmp_dir!(), "lux_cargo_test_#{System.unique_integer([:positive])}")

    try do
      manifest = Cargo.new_manifest(package: %{name: "lux_fixture"})

      assert {:ok, manifest_path} = Cargo.ensure_project(project_path, manifest: manifest)
      assert File.exists?(manifest_path)
      assert File.exists?(Path.join([project_path, "src", "lib.rs"]))
      assert File.read!(manifest_path) =~ ~s(name = "lux_fixture")

      File.write!(Path.join([project_path, "src", "lib.rs"]), "pub fn custom() -> bool { false }")
      assert {:ok, ^manifest_path} = Cargo.ensure_project(project_path, manifest: manifest)
      assert File.read!(Path.join([project_path, "src", "lib.rs"])) =~ "custom"
    after
      File.rm_rf!(project_path)
    end
  end
end
