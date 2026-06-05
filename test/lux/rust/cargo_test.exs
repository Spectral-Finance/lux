defmodule Lux.Rust.CargoTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Cargo

  describe "add_dependency/2" do
    test "accepts name and version" do
      assert {:ok, dep} = Cargo.add_dependency("serde", "~> 1.0")
      assert dep.name == "serde"
      assert dep.version == "~> 1.0"
      assert dep.added == true
    end

    test "uses default version when not provided" do
      assert {:ok, dep} = Cargo.add_dependency("reqwest")
      assert dep.name == "reqwest"
      assert dep.version == "*"
    end
  end

  describe "resolve_crate/2" do
    test "resolves a crate name" do
      assert {:ok, info} = Cargo.resolve_crate("tokio", "1")
      assert info.name == "tokio"
      assert info.version == "1"
      assert info.resolved == true
    end
  end

  describe "dependency_available?/1" do
    test "returns false for unknown dependency" do
      assert {:ok, false} = Cargo.dependency_available?("non_existent_crate_xyz")
    end
  end

  describe "parse_cargo_toml/1" do
    test "parses simple version-string dependencies" do
      toml = """
      [dependencies]
      serde = "1.0"
      reqwest = "0.11"
      tokio = { version = "1.0", features = ["full"] }
      """

      assert {:ok, deps} = Cargo.parse_cargo_toml(toml)
      assert length(deps) == 3

      serde = Enum.find(deps, &(&1.name == "serde"))
      assert serde.version == "1.0"

      tokio = Enum.find(deps, &(&1.name == "tokio"))
      assert tokio.version == "1.0"
      assert tokio.features == ["full"]
    end

    test "parses git and path dependencies" do
      toml = """
      [dependencies]
      my_crate = { git = "https://github.com/user/my_crate", branch = "main" }
      local_lib = { path = "../local_lib" }
      """

      assert {:ok, deps} = Cargo.parse_cargo_toml(toml)
      assert length(deps) == 2

      git_dep = Enum.find(deps, &(&1.name == "my_crate"))
      assert git_dep.source == :git
      assert git_dep.branch == "main"

      path_dep = Enum.find(deps, &(&1.name == "local_lib"))
      assert path_dep.source == :path
    end

    test "handles empty dependencies" do
      assert {:ok, []} = Cargo.parse_cargo_toml("")
    end

    test "handles comments and blank lines" do
      toml = """
      # This is a comment
      [dependencies]
      serde = "1.0"

      # Another comment
      [dev-dependencies]
      rstest = "0.15"
      """

      assert {:ok, deps} = Cargo.parse_cargo_toml(toml)
      assert length(deps) == 2
    end
  end

  describe "version/0" do
    test "returns version info" do
      v = Cargo.version()
      assert v.major == 0
      assert v.feature == :elixir_fallback
    end
  end
end
