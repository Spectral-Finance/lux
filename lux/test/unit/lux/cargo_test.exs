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

    test "updating a dependency overwrites the version" do
      manifest =
        "app"
        |> Cargo.new_manifest("0.1.0")
        |> Cargo.add_dependency("serde", "1.0")
        |> Cargo.add_dependency("serde", "1.1")

      assert Cargo.get_dependency(manifest, "serde") == "1.1"
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

    test "sorts dependencies deterministically" do
      toml =
        "app"
        |> Cargo.new_manifest("0.1.0")
        |> Cargo.add_dependency("tokio", "1.35")
        |> Cargo.add_dependency("serde", "1.0")
        |> Cargo.to_toml()

      assert :binary.match(toml, "serde") < :binary.match(toml, "tokio")
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

    test "ignores unknown sections and comments" do
      toml = """
      # a comment
      [package]
      name = "app"
      version = "0.1.0"

      [profile.release]
      opt-level = "3"
      """

      assert {:ok, manifest} = Cargo.from_toml(toml)
      assert manifest.package.name == "app"
      assert manifest.dependencies == %{}
    end

    test "returns an error for a manifest without package details" do
      assert {:error, message} = Cargo.from_toml("[dependencies]\nserde = \"1.0\"\n")
      assert message =~ "missing package name or version"
    end

    test "round-trips through to_toml/1 and from_toml/1" do
      manifest =
        "app"
        |> Cargo.new_manifest("0.1.0")
        |> Cargo.add_dependency("serde", "1.0")

      assert {:ok, parsed} = manifest |> Cargo.to_toml() |> Cargo.from_toml()
      assert parsed == manifest
    end
  end

  describe "file helpers" do
    @describetag :tmp_dir

    test "writes and reads a manifest", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "Cargo.toml")

      manifest =
        "app"
        |> Cargo.new_manifest("0.1.0")
        |> Cargo.add_dependency("serde", "1.0")

      assert :ok = Cargo.write_manifest(manifest, path)
      assert {:ok, ^manifest} = Cargo.read_manifest(path)
    end

    test "read_manifest/1 returns an error for a missing file", %{tmp_dir: tmp_dir} do
      assert {:error, message} = Cargo.read_manifest(Path.join(tmp_dir, "nope.toml"))
      assert message =~ "failed to read"
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

    test "clear_cache/0 removes cached packages" do
      assert :ok = Cargo.cache_package("serde", "1.0")
      assert :ok = Cargo.clear_cache()
      assert Cargo.cached_package("serde") == nil
    end
  end

  describe "cargo CLI wrappers" do
    test "version/0 reports missing cargo cleanly when unavailable" do
      case Cargo.version() do
        {:ok, output} -> assert output =~ "cargo"
        {:error, message} -> assert message =~ "cargo executable not found"
      end
    end
  end
end
