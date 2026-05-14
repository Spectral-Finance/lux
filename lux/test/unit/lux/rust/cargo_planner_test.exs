defmodule Lux.Rust.CargoPlannerTest do
  use UnitCase, async: true

  alias Lux.Rust.CargoPlanner

  test "normalizes manifests and round-trips Cargo.toml" do
    manifest =
      CargoPlanner.manifest(
        name: "lux_native",
        version: "0.2.0",
        dependencies: %{
          serde: [version: "1", features: ["derive"]],
          serde_json: "1"
        },
        features: %{default: ["serde/derive"]}
      )

    toml = CargoPlanner.to_toml(manifest)
    parsed = CargoPlanner.from_toml(toml)

    assert toml =~ "[package]"
    assert toml =~ ~s(name = "lux_native")
    assert parsed.package["version"] == "0.2.0"
    assert parsed.dependencies["serde"].features == ["derive"]
    assert parsed.dependencies["serde_json"].requirement == "1"
    assert parsed.features["default"] == ["serde/derive"]
  end

  test "resolves highest compatible dependency versions" do
    manifest =
      CargoPlanner.manifest(
        dependencies: %{
          serde: "~> 1.0",
          rustler: "^0.36",
          local_helper: [path: "../local_helper"]
        }
      )

    resolved =
      CargoPlanner.resolve_dependencies(manifest, %{
        "serde" => ["1.0.120", "1.0.197", "2.0.0"],
        "rustler" => ["0.35.0", "0.36.2", "0.37.0"]
      })

    assert resolved["serde"].selected == "1.0.197"
    assert resolved["rustler"].selected == "0.36.2"
    assert resolved["local_helper"].satisfied?
  end

  test "detects duplicate dependency requirement conflicts" do
    conflicts =
      CargoPlanner.dependency_conflicts([
        {:serde, "1"},
        {:serde, "2"},
        {:serde_json, "1"}
      ])

    assert conflicts == [%{name: "serde", requirements: ["1", "2"]}]
  end

  test "parses Cargo.lock package summaries" do
    lock = """
    [[package]]
    name = "serde"
    version = "1.0.197"
    source = "registry+https://github.com/rust-lang/crates.io-index"
    checksum = "abc"

    [[package]]
    name = "serde_json"
    version = "1.0.115"
    checksum = "def"
    """

    parsed = CargoPlanner.parse_lock(lock)

    assert parsed.package_count == 2
    assert Enum.map(parsed.packages, & &1.name) == ["serde", "serde_json"]
    assert parsed.checksums == ["abc", "def"]
  end

  test "builds fetch build and test commands" do
    manifest = CargoPlanner.manifest(name: "lux_native")

    build =
      CargoPlanner.build_plan(manifest,
        manifest_path: "priv/rust/lux_native/Cargo.toml",
        profile: :release,
        features: ["nif", "serde"],
        offline?: true
      )

    assert build.package == "lux_native"

    assert build.fetch == [
             "cargo",
             "fetch",
             "--manifest-path",
             "priv/rust/lux_native/Cargo.toml",
             "--locked",
             "--offline"
           ]

    assert build.build == [
             "cargo",
             "build",
             "--manifest-path",
             "priv/rust/lux_native/Cargo.toml",
             "--locked",
             "--offline",
             "--release",
             "--features",
             "nif,serde"
           ]

    assert build.test == [
             "cargo",
             "test",
             "--manifest-path",
             "priv/rust/lux_native/Cargo.toml",
             "--locked",
             "--offline",
             "--release",
             "--features",
             "nif,serde"
           ]
  end

  test "creates stable cache plans that include lock checksums" do
    manifest = CargoPlanner.manifest(name: "lux_native", dependencies: %{serde: "1"})
    lock_a = %{checksums: ["abc"]}
    lock_b = %{checksums: ["def"]}

    cache_a = CargoPlanner.cache_plan(manifest, lock_a, cache_root: ".cache/cargo")
    cache_b = CargoPlanner.cache_plan(manifest, lock_b, cache_root: ".cache/cargo")

    assert byte_size(cache_a.key) == 64
    assert cache_a.key != cache_b.key
    assert cache_a.directory == ".cache/cargo/#{cache_a.key}"
    assert "Cargo.lock" in cache_a.tracked_paths
  end

  test "produces a complete package-management plan" do
    plan =
      CargoPlanner.plan(
        name: "lux_native",
        dependencies: %{serde: "~> 1.0"},
        version_index: %{"serde" => ["1.0.197"]},
        features: %{default: ["serde/derive"]}
      )

    assert plan.resolved_dependencies["serde"].selected == "1.0.197"
    assert plan.conflicts == []
    assert plan.cargo_toml =~ "[dependencies]"
    assert :cargo_toml_management in plan.coverage
    assert :package_caching in plan.coverage
  end
end
