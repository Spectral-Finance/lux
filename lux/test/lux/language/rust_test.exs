defmodule Lux.Language.RustTest do
  use ExUnit.Case, async: true

  alias Lux.Language.Rust

  @tmp_dir Path.join(System.tmp_dir!(), "lux_rust_test_#{:erlang.unique_integer([:positive])}")

  setup_all do
    File.mkdir_p!(@tmp_dir)
    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    :ok
  end

  test "generate_cargo_toml/2 creates a valid Cargo.toml string" do
    toml = Rust.generate_cargo_toml("my_lib", [{"serde", "1.0"}, {"tokio", "1.28"}])

    assert String.contains?(toml, ~s(name = "my_lib"))
    assert String.contains?(toml, ~s(serde = "1.0"))
    assert String.contains?(toml, ~s(tokio = "1.28"))
  end

  test "parse_cargo_toml/1 reads back the generated file" do
    path = Path.join(@tmp_dir, "Cargo.toml")
    content = Rust.generate_cargo_toml("parse_test", [{"rand", "0.8"}])
    File.write!(path, content)

    assert {:ok, map} = Rust.parse_cargo_toml(path)
    assert map["package"]["name"] == "parse_test"
    assert map["dependencies"]["rand"] == "0.8"
  end

  test "build_project/1 builds a minimal crate" do
    project = Path.join(@tmp_dir, "dummy")
    File.mkdir_p!(project)

    # Write Cargo.toml and a trivial lib.rs
    File.write!(Path.join(project, "Cargo.toml"), Rust.generate_cargo_toml("dummy", []))

    src_dir = Path.join([project, "src"])
    File.mkdir_p!(src_dir)
    File.write!(Path.join(src_dir, "lib.rs"), "pub fn hello() -> &'static str { \"world\" }")

    # Build
    assert :ok = Rust.build_project(project)

    # Verify that the binary artifact exists
    release_dir = Path.join([project, "target", "release"])
    assert File.dir?(release_dir)
  end

  test "cache_package/1 stores compiled artifacts and fetch_cached/2 retrieves them" do
    project = Path.join(@tmp_dir, "cache_demo")
    File.mkdir_p!(project)

    File.write!(Path.join(project, "Cargo.toml"), Rust.generate_cargo_toml("cache_demo", []))

    src_dir = Path.join([project, "src"])
    File.mkdir_p!(src_dir)
    File.write!(Path.join(src_dir, "lib.rs"), "pub fn answer() -> i32 { 42 }")

    # Build the crate first
    assert :ok = Rust.build_project(project)

    # Cache it
    assert :ok = Rust.cache_package(project)

    # Extract name/version from Cargo.toml
    {:ok, toml} = Rust.parse_cargo_toml(Path.join(project, "Cargo.toml"))
    %{"package" => %{"name" => name, "version" => version}} = toml

    # Fetch from cache
    assert {:ok, cached_path} = Rust.fetch_cached(name, version)
    assert File.dir?(cached_path)
    # The cached directory should contain the compiled library file (platform dependent)
    assert Enum.any?(File.ls!(cached_path), fn file -> String.ends_with?(file, ".rlib") end)
  end
end
