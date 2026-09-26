defmodule Lux.Rust.CargoTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Cargo

  describe "manifest management" do
    test "creates a new default manifest" do
      manifest = Cargo.new_manifest("my_agent_crate", version: "0.2.0")
      assert manifest.package.name == "my_agent_crate"
      assert manifest.package.version == "0.2.0"
      assert manifest.package.edition == "2021"
    end

    test "adds and removes dependencies" do
      manifest = Cargo.new_manifest("test_pkg")
      {:ok, with_dep} = Cargo.add_dependency(manifest, "serde", "1.0")
      assert with_dep.dependencies["serde"] == "1.0"
      {:ok, removed} = Cargo.remove_dependency(with_dep, "serde")
      assert removed.dependencies["serde"] == nil
    end

    test "serializes manifest to valid TOML" do
      manifest =
        Cargo.new_manifest("lux_math")
        |> (fn m ->
              {:ok, m1} = Cargo.add_dependency(m, "tokio", "1.30")
              m1
            end).()

      toml = Cargo.to_toml(manifest)
      assert String.contains?(toml, "[package]")
      assert String.contains?(toml, "name = \"lux_math\"")
      assert String.contains?(toml, "tokio = \"1.30\"")
    end

    test "parses Cargo.toml string ignoring comments" do
      toml = """
      [package]
      name = "lux_agent_core"
      version = "1.0.0"
      edition = "2021"

      [dependencies]
      # Dependencia essencial
      reqwest = "0.11"
      serde_json = "1.0"
      """

      {:ok, parsed} = Cargo.parse_manifest(toml)
      assert parsed.package.name == "lux_agent_core"
      assert parsed.dependencies["reqwest"] == "0.11"
      assert parsed.dependencies["serde_json"] == "1.0"
    end
  end
end
