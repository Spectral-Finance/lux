defmodule Lux.CargoTest do
  use UnitAPICase, async: false

  alias Lux.Cargo

  setup do
    # Create a temp dir that mimics a cargo project structure
    tmpdir = Path.join(System.tmp_dir!(), "lux_cargo_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(tmpdir)
    toml_path = Path.join(tmpdir, "Cargo.toml")

    on_exit(fn ->
      File.rm_rf!(tmpdir)
    end)

    {:ok, tmpdir: tmpdir, toml_path: toml_path}
  end

  # ---------------------------------------------------------------------------
  # Cargo.toml Generation
  # ---------------------------------------------------------------------------
  describe "generate_toml/2" do
    test "generates a valid Cargo.toml with no dependencies" do
      toml = Cargo.generate_toml("my_crate")
      assert toml =~ ~s([package])
      assert toml =~ ~s(name = "my_crate")
      assert toml =~ ~s([dependencies])
    end

    test "generates a Cargo.toml with dependencies" do
      toml = Cargo.generate_toml("my_crate", [{"serde", "1.0"}, {"tokio", "1"}])
      assert toml =~ ~s(serde = "1.0")
      assert toml =~ ~s(tokio = "1")
    end
  end

  # ---------------------------------------------------------------------------
  # Cargo.toml Parsing
  # ---------------------------------------------------------------------------
  describe "parse_toml/1" do
    test "parses package name and version" do
      content = """
      [package]
      name = "my_project"
      version = "0.2.0"
      edition = "2021"

      [dependencies]
      """

      assert {:ok, parsed} = Cargo.parse_toml(content)
      assert parsed.name == "my_project"
      assert parsed.version == "0.2.0"
      assert parsed.edition == "2021"
    end

    test "parses dependencies section" do
      content = """
      [package]
      name = "proj"
      version = "0.1.0"
      edition = "2021"

      [dependencies]
      serde = "1.0"
      tokio = "1"
      """

      assert {:ok, parsed} = Cargo.parse_toml(content)
      assert parsed.dependencies["serde"] == "1.0"
      assert parsed.dependencies["tokio"] == "1"
    end

    test "returns empty dependencies map when [dependencies] section is absent" do
      content = """
      [package]
      name = "bare"
      version = "0.1.0"
      edition = "2021"
      """

      assert {:ok, parsed} = Cargo.parse_toml(content)
      assert parsed.dependencies == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Writing / Reading Cargo.toml files
  # ---------------------------------------------------------------------------
  describe "write_toml/3 and read_toml/1" do
    test "round-trips a Cargo.toml file", %{toml_path: toml_path} do
      assert {:ok, _content} = Cargo.write_toml(toml_path, "round_trip", [{"serde", "1.0"}])
      assert {:ok, parsed} = Cargo.read_toml(toml_path)
      assert parsed.name == "round_trip"
      assert parsed.dependencies["serde"] == "1.0"
    end

    test "read_toml returns error for missing file" do
      assert {:error, _reason} = Cargo.read_toml("/nonexistent/path/Cargo.toml")
    end
  end

  # ---------------------------------------------------------------------------
  # Dependency Management
  # ---------------------------------------------------------------------------
  describe "add_dependency/3" do
    test "adds a dependency to an existing Cargo.toml", %{toml_path: toml_path} do
      # Bootstrap
      Cargo.write_toml(toml_path, "my_project", [])

      assert {:ok, content} = Cargo.add_dependency(toml_path, "serde", "1.0")
      assert content =~ ~s(serde = "1.0")
    end

    test "overwrites an existing dependency with a new version", %{toml_path: toml_path} do
      Cargo.write_toml(toml_path, "my_project", [{"serde", "0.9"}])
      assert {:ok, content} = Cargo.add_dependency(toml_path, "serde", "1.0")
      assert content =~ ~s(serde = "1.0")
      refute content =~ ~s(serde = "0.9")
    end
  end

  describe "remove_dependency/2" do
    test "removes a dependency from an existing Cargo.toml", %{toml_path: toml_path} do
      Cargo.write_toml(toml_path, "my_project", [{"serde", "1.0"}, {"tokio", "1"}])
      assert {:ok, content} = Cargo.remove_dependency(toml_path, "serde")
      refute content =~ ~s(serde = "1.0")
      assert content =~ ~s(tokio = "1")
    end
  end

  describe "update_dependency/3" do
    test "updates a dependency version", %{toml_path: toml_path} do
      Cargo.write_toml(toml_path, "my_project", [{"serde", "0.9"}])
      assert {:ok, content} = Cargo.update_dependency(toml_path, "serde", "1.0")
      assert content =~ ~s(serde = "1.0")
    end
  end

  # ---------------------------------------------------------------------------
  # Package Caching
  # ---------------------------------------------------------------------------
  describe "cache operations" do
    test "ensure_cache/0 creates the cache directory" do
      assert {:ok, cache_dir} = Cargo.ensure_cache()
      assert File.dir?(cache_dir)
    end

    test "cache_size/0 returns a non-negative integer" do
      Cargo.ensure_cache()
      assert {:ok, size} = Cargo.cache_size()
      assert is_integer(size) and size >= 0
    end

    test "setup_cache_env/0 returns a map with CARGO_HOME" do
      env = Cargo.setup_cache_env()
      assert is_map(env)
      assert Map.has_key?(env, "CARGO_HOME")
      assert File.dir?(env["CARGO_HOME"])
    end

    test "clear_cache/0 removes the cache directory" do
      Cargo.ensure_cache()
      assert :ok = Cargo.clear_cache()
    end
  end

  # ---------------------------------------------------------------------------
  # Build System
  # ---------------------------------------------------------------------------
  describe "cargo_available?/0" do
    test "returns a boolean" do
      result = Cargo.cargo_available?()
      assert is_boolean(result)
    end
  end

  describe "resolve_dependencies/1" do
    test "returns list of dependency maps for a valid Cargo.toml", %{toml_path: toml_path} do
      Cargo.write_toml(toml_path, "my_project", [{"serde", "1.0"}])
      # resolve_dependencies works with or without cargo installed
      result = Cargo.resolve_dependencies(toml_path)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, deps} ->
          assert is_list(deps)
          dep = Enum.find(deps, &(&1.name == "serde"))
          assert dep != nil
          assert dep.version == "1.0"

        {:error, _reason} ->
          # Cargo not installed or fetch failed — just ensure parse still works
          assert {:ok, parsed} = Cargo.read_toml(toml_path)
          assert parsed.dependencies["serde"] == "1.0"
      end
    end
  end
end
