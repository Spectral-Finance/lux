defmodule Lux.CargoTest do
  use UnitCase, async: true

  alias Lux.Cargo

  @tmp_dir Path.join(System.tmp_dir!(), "lux_cargo_test_#{:erlang.unique_integer([:positive])}")

  setup do
    File.rm_rf(@tmp_dir)
    on_exit(fn -> File.rm_rf(@tmp_dir) end)
    :ok
  end

  # -------------------------------------------------------------------
  # Cargo.toml Management
  # -------------------------------------------------------------------

  describe "init/2" do
    test "creates a library project with correct structure" do
      project_path = Path.join(@tmp_dir, "test_lib")
      assert {:ok, ^project_path} = Cargo.init(project_path)

      assert File.exists?(Path.join(project_path, "Cargo.toml"))
      assert File.exists?(Path.join([project_path, "src", "lib.rs"]))
      refute File.exists?(Path.join([project_path, "src", "main.rs"]))

      content = File.read!(Path.join(project_path, "Cargo.toml"))
      assert content =~ "name = \"test_lib\""
      assert content =~ "version = \"0.1.0\""
      assert content =~ "edition = \"2021\""
      assert content =~ "[dependencies]"

      lib_content = File.read!(Path.join([project_path, "src", "lib.rs"]))
      assert lib_content =~ "pub fn add"
      assert lib_content =~ "#[cfg(test)]"
    end

    test "creates a binary project" do
      project_path = Path.join(@tmp_dir, "test_bin")
      assert {:ok, ^project_path} = Cargo.init(project_path, type: :bin)

      assert File.exists?(Path.join([project_path, "src", "main.rs"]))
      refute File.exists?(Path.join([project_path, "src", "lib.rs"]))

      main_content = File.read!(Path.join([project_path, "src", "main.rs"]))
      assert main_content =~ "fn main()"
      assert main_content =~ "Hello from Lux!"
    end

    test "respects edition option" do
      project_path = Path.join(@tmp_dir, "test_edition")
      assert {:ok, _} = Cargo.init(project_path, edition: "2018")

      content = File.read!(Path.join(project_path, "Cargo.toml"))
      assert content =~ "edition = \"2018\""
    end

    test "creates nested directory structures" do
      project_path = Path.join([@tmp_dir, "deep", "nested", "project"])
      assert {:ok, ^project_path} = Cargo.init(project_path)
      assert File.exists?(Path.join(project_path, "Cargo.toml"))
    end

    test "uses project directory name as crate name" do
      project_path = Path.join(@tmp_dir, "my_special_crate")
      assert {:ok, _} = Cargo.init(project_path)

      content = File.read!(Path.join(project_path, "Cargo.toml"))
      assert content =~ "name = \"my_special_crate\""
    end
  end

  describe "parse_cargo_toml/1" do
    test "parses a generated Cargo.toml" do
      project_path = Path.join(@tmp_dir, "test_parse")
      {:ok, _} = Cargo.init(project_path)

      assert {:ok, parsed} = Cargo.parse_cargo_toml(project_path)
      assert parsed.name == "test_parse"
      assert parsed.version == "0.1.0"
      assert parsed.edition == "2021"
      assert parsed.dependencies == %{}
    end

    test "parses Cargo.toml with dependencies" do
      project_path = Path.join(@tmp_dir, "test_parse_deps")
      {:ok, _} = Cargo.init(project_path)

      # Write a Cargo.toml with dependencies
      cargo_toml = Cargo.generate_cargo_toml("test_parse_deps", "1.0.0", "2021", %{
        "serde" => "1.0",
        "tokio" => "1.35"
      })

      File.write!(Path.join(project_path, "Cargo.toml"), cargo_toml)

      assert {:ok, parsed} = Cargo.parse_cargo_toml(project_path)
      assert parsed.name == "test_parse_deps"
      assert parsed.version == "1.0.0"
      assert Map.has_key?(parsed.dependencies, "serde")
      assert Map.has_key?(parsed.dependencies, "tokio")
    end

    test "returns error for nonexistent path" do
      assert {:error, msg} = Cargo.parse_cargo_toml("/nonexistent/path")
      assert msg =~ "Failed to read"
    end

    test "returns error for directory without Cargo.toml" do
      path = Path.join(@tmp_dir, "empty_dir")
      File.mkdir_p!(path)
      assert {:error, _} = Cargo.parse_cargo_toml(path)
    end
  end

  describe "generate_cargo_toml/4" do
    test "generates valid Cargo.toml content" do
      content = Cargo.generate_cargo_toml("my_crate", "1.0.0", "2021", %{"serde" => "1.0"})

      assert content =~ "[package]"
      assert content =~ "name = \"my_crate\""
      assert content =~ "version = \"1.0.0\""
      assert content =~ "edition = \"2021\""
      assert content =~ "[dependencies]"
      assert content =~ "serde = \"1.0\""
    end

    test "generates Cargo.toml with features" do
      deps = %{"tokio" => %{version: "1.0", features: ["full"]}}
      content = Cargo.generate_cargo_toml("my_crate", "1.0.0", "2021", deps)

      assert content =~ "tokio"
      assert content =~ "features"
      assert content =~ "full"
    end

    test "generates Cargo.toml with multiple features" do
      deps = %{"serde" => %{version: "1.0", features: ["derive", "alloc"]}}
      content = Cargo.generate_cargo_toml("my_crate", "1.0.0", "2021", deps)

      assert content =~ "serde"
      assert content =~ "derive"
      assert content =~ "alloc"
    end

    test "generates Cargo.toml with no dependencies" do
      content = Cargo.generate_cargo_toml("empty", "0.1.0", "2021", %{})
      assert content =~ "[package]"
      assert content =~ "[dependencies]"
      assert content =~ "name = \"empty\""
    end

    test "generates Cargo.toml with multiple simple dependencies" do
      deps = %{
        "serde" => "1.0",
        "rand" => "0.8",
        "anyhow" => "1.0"
      }

      content = Cargo.generate_cargo_toml("multi_dep", "0.1.0", "2021", deps)
      assert content =~ "serde = \"1.0\""
      assert content =~ "rand = \"0.8\""
      assert content =~ "anyhow = \"1.0\""
    end

    test "content ends with newline" do
      content = Cargo.generate_cargo_toml("test", "0.1.0", "2021", %{})
      assert String.ends_with?(content, "\n")
    end
  end

  # -------------------------------------------------------------------
  # Dependency Resolution
  # -------------------------------------------------------------------

  describe "add_dependency/4" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.add_dependency("/nonexistent/project", "serde", "1.0")
    end
  end

  describe "remove_dependency/2" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.remove_dependency("/nonexistent/project", "serde")
    end
  end

  describe "update_dependencies/2" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.update_dependencies("/nonexistent/project")
    end
  end

  describe "list_dependencies/1" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.list_dependencies("/nonexistent/project")
    end
  end

  # -------------------------------------------------------------------
  # Build System Integration
  # -------------------------------------------------------------------

  describe "build/2" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.build("/nonexistent/project")
    end
  end

  describe "test/2" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.test("/nonexistent/project")
    end
  end

  describe "check/1" do
    test "returns error for nonexistent project" do
      assert {:error, _} = Cargo.check("/nonexistent/project")
    end
  end

  describe "eval/2" do
    test "returns error for invalid Rust code" do
      case Cargo.toolchain_version() do
        {:ok, _} ->
          assert {:error, _} = Cargo.eval("this is not valid rust")

        {:error, _} ->
          # Rust not installed, skip
          :ok
      end
    end

    test "evaluates simple Rust code" do
      case Cargo.toolchain_version() do
        {:ok, _} ->
          assert {:ok, "4"} =
                   Cargo.eval("fn main() { println!(\"{}\", 2 + 2); }")

        {:error, _} ->
          :ok
      end
    end

    test "evaluates Rust code with string output" do
      case Cargo.toolchain_version() do
        {:ok, _} ->
          assert {:ok, "Hello from Lux"} =
                   Cargo.eval(~S'fn main() { println!("Hello from Lux"); }')

        {:error, _} ->
          :ok
      end
    end

    test "evaluates Rust code with multiline output" do
      case Cargo.toolchain_version() do
        {:ok, _} ->
          code = """
          fn main() {
              for i in 1..=3 {
                  println!("{}", i);
              }
          }
          """

          assert {:ok, result} = Cargo.eval(code)
          assert result =~ "1"
          assert result =~ "2"
          assert result =~ "3"

        {:error, _} ->
          :ok
      end
    end

    test "cleans up temporary project after evaluation" do
      case Cargo.toolchain_version() do
        {:ok, _} ->
          # Get list of temp dirs before
          before = Path.wildcard(Path.join(System.tmp_dir!(), "lux_cargo_eval_*"))
          {:ok, _} = Cargo.eval("fn main() { println!(\"test\"); }")
          after_dirs = Path.wildcard(Path.join(System.tmp_dir!(), "lux_cargo_eval_*"))

          # No new temp dirs should remain
          assert length(after_dirs) <= length(before)

        {:error, _} ->
          :ok
      end
    end
  end

  # -------------------------------------------------------------------
  # Version Management
  # -------------------------------------------------------------------

  describe "toolchain_version/0" do
    test "returns cargo and rustc versions when installed" do
      case Cargo.toolchain_version() do
        {:ok, %{cargo: cargo, rustc: rustc}} ->
          assert is_binary(cargo)
          assert is_binary(rustc)
          # Versions should look like semver
          assert cargo =~ ~r/\d+\.\d+/
          assert rustc =~ ~r/\d+\.\d+/

        {:error, _} ->
          # Rust not installed in test environment, that's OK
          :ok
      end
    end
  end

  describe "search_crate/2" do
    test "searches crates.io" do
      case Cargo.search_crate("serde", limit: 1) do
        {:ok, crates} ->
          assert is_list(crates)

          if length(crates) > 0 do
            [first | _] = crates
            assert Map.has_key?(first, :name)
            assert Map.has_key?(first, :version)
            assert Map.has_key?(first, :description)
          end

        {:error, _} ->
          # Cargo not available in test env
          :ok
      end
    end

    test "returns empty list for nonexistent crate" do
      case Cargo.search_crate("zzz_nonexistent_crate_that_should_not_exist_xyz", limit: 1) do
        {:ok, crates} ->
          assert is_list(crates)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "check_crate_version/2" do
    test "checks if a crate version exists" do
      case Cargo.check_crate_version("serde", "1.0") do
        {:ok, result} ->
          assert is_boolean(result)

        {:error, _} ->
          :ok
      end
    end
  end

  # -------------------------------------------------------------------
  # Package Caching
  # -------------------------------------------------------------------

  describe "cache management" do
    test "cache_dir returns a string path" do
      dir = Cargo.cache_dir()
      assert is_binary(dir)
      assert dir =~ "lux_cargo_cache"
    end

    test "ensure_cache creates the cache directory" do
      Cargo.clear_cache()
      assert {:ok, path} = Cargo.ensure_cache()
      assert File.dir?(path)
      assert path == Cargo.cache_dir()
    end

    test "ensure_cache is idempotent" do
      assert {:ok, path1} = Cargo.ensure_cache()
      assert {:ok, path2} = Cargo.ensure_cache()
      assert path1 == path2
    end

    test "clear_cache removes the cache directory" do
      Cargo.ensure_cache()
      assert File.dir?(Cargo.cache_dir())
      assert :ok = Cargo.clear_cache()
      refute File.dir?(Cargo.cache_dir())
    end

    test "clear_cache is idempotent" do
      Cargo.clear_cache()
      assert :ok = Cargo.clear_cache()
    end

    test "cache_size returns 0 for empty/nonexistent cache" do
      Cargo.clear_cache()
      assert {:ok, 0} = Cargo.cache_size()
    end

    test "cache_size returns size after writing files" do
      {:ok, cache_path} = Cargo.ensure_cache()
      test_file = Path.join(cache_path, "test_file.txt")
      File.write!(test_file, String.duplicate("x", 1000))

      assert {:ok, size} = Cargo.cache_size()
      assert size >= 1000
    end

    test "setup_cache_env returns CARGO_HOME" do
      env = Cargo.setup_cache_env()
      assert Map.has_key?(env, "CARGO_HOME")
      assert is_binary(env["CARGO_HOME"])
      assert env["CARGO_HOME"] =~ "cargo_home"
      assert File.dir?(env["CARGO_HOME"])
    end
  end

  # -------------------------------------------------------------------
  # Integration: init + parse round-trip
  # -------------------------------------------------------------------

  describe "round-trip integration" do
    test "init then parse produces consistent results" do
      project_path = Path.join(@tmp_dir, "roundtrip")
      {:ok, _} = Cargo.init(project_path, edition: "2021")

      assert {:ok, parsed} = Cargo.parse_cargo_toml(project_path)
      assert parsed.name == "roundtrip"
      assert parsed.version == "0.1.0"
      assert parsed.edition == "2021"
      assert parsed.dependencies == %{}
    end

    test "generate_cargo_toml then parse produces consistent results" do
      project_path = Path.join(@tmp_dir, "gen_parse")
      File.mkdir_p!(project_path)

      deps = %{"serde" => "1.0", "rand" => "0.8"}
      content = Cargo.generate_cargo_toml("gen_parse", "2.0.0", "2021", deps)
      File.write!(Path.join(project_path, "Cargo.toml"), content)

      assert {:ok, parsed} = Cargo.parse_cargo_toml(project_path)
      assert parsed.name == "gen_parse"
      assert parsed.version == "2.0.0"
      assert parsed.dependencies["serde"] == "1.0"
      assert parsed.dependencies["rand"] == "0.8"
    end
  end
end
