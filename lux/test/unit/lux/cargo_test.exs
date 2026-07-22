defmodule Lux.CargoTest do
  use UnitCase, async: true

  alias Lux.Cargo

  describe "manifest management" do
    test "creates a new manifest with defaults" do
      manifest = Cargo.new_manifest("my_agent", "0.1.0")

      assert manifest.package.name == "my_agent"
      assert manifest.package.version == "0.1.0"
      assert manifest.package.edition == "2021"
      assert manifest.dependencies == %{}
    end

    test "supports a custom edition" do
      manifest = Cargo.new_manifest("my_agent", "0.1.0", edition: "2018")
      assert manifest.package.edition == "2018"
    end

    test "adds, reads and removes dependencies" do
      manifest =
        "app"
        |> Cargo.new_manifest("0.1.0")
        |> Cargo.add_dependency("serde", "1.0")
        |> Cargo.add_dependency("tokio", "1.35")

      assert Cargo.get_dependency(manifest, "serde") == "1.0"
      assert Cargo.get_dependency(manifest, "tokio") == "1.35"
      assert Cargo.get_dependency(manifest, "missing") == nil

      manifest = Cargo.remove_dependency(manifest, "serde")
      assert Cargo.get_dependency(manifest, "serde") == nil
      assert Cargo.get_dependency(manifest, "tokio") == "1.35"
    end
  end

  describe "to_toml/1" do
    test "renders package and dependency sections" do
      toml =
        "app"
        |> Cargo.new_manifest("0.1.0")
        |> Cargo.add_dependency("serde", "1.0")
        |> Cargo.to_toml()

      assert toml =~ "[package]"
      assert toml =~ ~s(name = "app")
      assert toml =~ ~s(version = "0.1.0")
      assert toml =~ ~s(edition = "2021")
      assert toml =~ "[dependencies]"
      assert toml =~ ~s(serde = "1.0")
    end
  end

  describe "from_toml/1" do
    test "parses a valid manifest" do
      toml = """
      [package]
      name = "app"
      version = "0.2.0"
      edition = "2018"

      [dependencies]
      serde = "1.0"
      tokio = "1.35"
      """

      assert {:ok, manifest} = Cargo.from_toml(toml)
      assert manifest.package.name == "app"
      assert manifest.package.version == "0.2.0"
      assert manifest.package.edition == "2018"
      assert manifest.dependencies == %{"serde" => "1.0", "tokio" => "1.35"}
    end

    test "parses inline tables and arrays" do
      toml = """
      [package]
      name = "app"
      version = "0.1.0"

      [dependencies]
      serde = { version = "1.0", features = ["derive"] }
      """

      assert {:ok, manifest} = Cargo.from_toml(toml)
      assert Map.get(manifest.dependencies, "serde") == %{"version" => "1.0", "features" => ["derive"]}
    end

    test "parses dotted section headers" do
      toml = """
      [package]
      name = "app"
      version = "0.1.0"

      [dependencies.serde]
      version = "1.0"
      features = ["derive"]
      """

      assert {:ok, manifest} = Cargo.from_toml(toml)
      assert get_in(manifest, ["dependencies", "serde", "version"]) == "1.0"
    end

    test "returns an error for a manifest without package details" do
      assert {:error, message} = Cargo.from_toml("[dependencies]\nserde = \"1.0\"\n")
      assert message =~ "missing package name or version"
    end
  end

  describe "package caching" do
    setup do
      Cargo.clear_cache()
      on_exit(fn -> Cargo.clear_cache() end)
      :ok
    end

    test "caches and reads a package version" do
      assert :ok = Cargo.cache_package("serde", "1.0.195")
      assert Cargo.cached_package("serde") == "1.0.195"
    end

    test "returns nil for an uncached package" do
      assert Cargo.cached_package("not_cached") == nil
    end
  end

  describe "missing toolchain error handling" do
    setup do
      # Back up actual configuration
      orig = Application.get_env(:lux, :cargo_bin)
      
      on_exit(fn ->
        if orig == nil do
          Application.delete_env(:lux, :cargo_bin)
        else
          Application.put_env(:lux, :cargo_bin, orig)
        end
      end)
      
      :ok
    end

    test "returns error tuple when cargo binary is missing" do
      Application.put_env(:lux, :cargo_bin, nil)

      assert {:error, message} = Cargo.version()
      assert message =~ "cargo executable not found"

      assert {:error, message} = Cargo.build()
      assert message =~ "cargo executable not found"

      assert {:error, message} = Cargo.test()
      assert message =~ "cargo executable not found"

      assert {:error, message} = Cargo.run("bin")
      assert message =~ "cargo executable not found"
    end
  end
end
