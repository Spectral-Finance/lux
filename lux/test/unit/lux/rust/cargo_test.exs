defmodule Lux.Rust.CargoTest do
  use UnitCase, async: true

  alias Lux.Rust.Cargo

  describe "manifest generation and parsing" do
    test "renders deterministic Cargo.toml content" do
      manifest =
        Cargo.manifest(
          name: "Lux Native",
          version: "0.2.0",
          dependencies: %{
            serde: %{version: "1", features: ["derive"]},
            serde_json: "1.0",
            local_tool: %{path: "../local_tool"}
          },
          dev_dependencies: %{proptest: "~1.4"},
          build_dependencies: %{cc: "1"},
          features: %{default: ["serde/derive"], nif: ["rustler"]}
        )

      toml = Cargo.to_toml(manifest)

      assert toml =~ ~s(name = "lux_native")
      assert toml =~ ~s(version = "0.2.0")
      assert toml =~ ~s(local_tool = { path = "../local_tool" })
      assert toml =~ ~s(serde = { version = "1", features = ["derive"] })
      assert toml =~ "[dev-dependencies]"
      assert toml =~ "[build-dependencies]"
      assert toml =~ ~s(default = ["serde/derive"])
    end

    test "round-trips generated Cargo.toml" do
      manifest =
        Cargo.manifest(
          name: "roundtrip",
          dependencies: [
            {:serde, %{version: "1", features: ["derive"], optional: true}},
            {:rustler, %{git: "https://github.com/rusterlium/rustler", tag: "v0.36.2"}}
          ],
          features: %{default: ["serde"]}
        )

      parsed = manifest |> Cargo.to_toml() |> Cargo.from_toml()

      assert parsed.package["name"] == "roundtrip"
      assert parsed.dependencies["serde"].requirement == "1"
      assert parsed.dependencies["serde"].optional?
      assert parsed.dependencies["serde"].features == ["derive"]
      assert parsed.dependencies["rustler"].source == :git
      assert parsed.dependencies["rustler"].tag == "v0.36.2"
      assert parsed.features["default"] == ["serde"]
    end

    test "reads and writes Cargo.toml files" do
      tmp_dir = tmp_dir()
      path = Path.join(tmp_dir, "Cargo.toml")
      manifest = Cargo.manifest(name: "file_test", dependencies: %{serde: "1"})

      assert :ok = Cargo.write_manifest(manifest, path)
      assert {:ok, parsed} = Cargo.read_manifest(path)
      assert parsed.package["name"] == "file_test"
      assert parsed.dependencies["serde"].requirement == "1"
    end

    test "initializes a minimal Cargo project" do
      tmp_dir = tmp_dir()

      assert {:ok, project} =
               Cargo.init_project(tmp_dir,
                 name: "Lux Native",
                 dependencies: %{serde: "1"}
               )

      assert File.regular?(project.manifest_path)
      assert File.regular?(project.src_path)
      assert File.read!(project.src_path) =~ "pub fn package_name()"

      assert {:error, {:already_exists, _path}} =
               Cargo.init_project(tmp_dir, name: "Lux Native")
    end
  end

  describe "dependency management" do
    test "adds and removes dependencies by scope" do
      manifest =
        Cargo.manifest(name: "deps")
        |> Cargo.add_dependency(:serde, "1", features: ["derive"])
        |> Cargo.add_dependency(:proptest, "~1.4", scope: :dev)
        |> Cargo.add_dependency(:cc, "1", scope: :build)

      assert manifest.dependencies["serde"].features == ["derive"]
      assert manifest.dev_dependencies["proptest"].requirement == "~1.4"
      assert manifest.build_dependencies["cc"].requirement == "1"

      manifest = Cargo.remove_dependency(manifest, :serde)
      refute Map.has_key?(manifest.dependencies, "serde")
    end

    test "detects requirement conflicts across sections" do
      manifest =
        Cargo.manifest(
          dependencies: %{serde: "1"},
          dev_dependencies: %{serde: "2"}
        )

      assert [%{name: "serde", requirements: requirements}] = Cargo.dependency_conflicts(manifest)
      assert Enum.sort(requirements) == ["1", "2"]
    end

    test "patches dependency sections without rewriting unrelated manifest content" do
      tmp_dir = tmp_dir()
      path = Path.join(tmp_dir, "Cargo.toml")

      original = """
      # workspace metadata must stay untouched
      [workspace]
      members = ["crates/*"]

      [package]
      name = "existing"
      version = "0.1.0"
      edition = "2021" # keep inline comments

      [lib]
      crate-type = ["cdylib"]

      [dependencies] # dependency comments are preserved
      serde = "1"
      tracing = "0.1" # keep existing dependency comments

      [target.'cfg(unix)'.dependencies]
      libc = "0.2"

      [[bin]]
      name = "worker"
      path = "src/bin/worker.rs"

      [profile.release]
      lto = true
      """

      File.write!(path, original)

      assert :ok =
               Cargo.add_dependency_to_file(path, :tokio,
                 version: "1",
                 features: ["rt-multi-thread"]
               )

      assert :ok = Cargo.add_dependency_to_file(path, :proptest, "~1.4", scope: :dev)
      assert :ok = Cargo.remove_dependency_from_file(path, :serde)

      assert File.read!(path) == """
             # workspace metadata must stay untouched
             [workspace]
             members = ["crates/*"]

             [package]
             name = "existing"
             version = "0.1.0"
             edition = "2021" # keep inline comments

             [lib]
             crate-type = ["cdylib"]

             [dependencies] # dependency comments are preserved
             tracing = "0.1" # keep existing dependency comments
             tokio = { version = "1", features = ["rt-multi-thread"] }

             [target.'cfg(unix)'.dependencies]
             libc = "0.2"

             [[bin]]
             name = "worker"
             path = "src/bin/worker.rs"

             [profile.release]
             lto = true

             [dev-dependencies]
             proptest = "~1.4"
             """
    end

    test "replaces existing dependencies in place" do
      tmp_dir = tmp_dir()
      path = Path.join(tmp_dir, "Cargo.toml")

      File.write!(path, """
      [dependencies]
      serde = "1"
      tokio = "1"
      tracing = "0.1"
      """)

      assert :ok =
               Cargo.add_dependency_to_file(path, :tokio,
                 version: "1",
                 features: ["rt-multi-thread"]
               )

      assert File.read!(path) == """
             [dependencies]
             serde = "1"
             tokio = { version = "1", features = ["rt-multi-thread"] }
             tracing = "0.1"
             """
    end
  end

  describe "dependency resolution and versions" do
    test "resolves registry dependencies from lockfile and version index" do
      manifest =
        Cargo.manifest(
          dependencies: %{
            serde: "^1.0",
            tokio: "~1.28",
            local_tool: %{path: "../local_tool"}
          }
        )

      lockfile = """
      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "registry+https://github.com/rust-lang/crates.io-index"
      checksum = "abc"
      """

      resolved =
        Cargo.resolve_dependencies(manifest,
          lockfile: lockfile,
          version_index: %{
            "serde" => ["1.0.198", "1.0.197"],
            "tokio" => ["1.29.0", "1.28.2", "2.0.0"]
          }
        )

      assert resolved["serde"].locked == "1.0.197"
      assert resolved["serde"].satisfied?
      assert resolved["tokio"].selected == "1.28.2"
      assert resolved["tokio"].satisfied?
      assert resolved["local_tool"].source == :path
      assert resolved["local_tool"].satisfied?
    end

    test "reports outdated locked dependencies" do
      manifest = Cargo.manifest(dependencies: %{serde: "^1.0", tokio: "1"})

      lockfile = """
      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "registry+https://github.com/rust-lang/crates.io-index"

      [[package]]
      name = "tokio"
      version = "1.28.2"
      source = "registry+https://github.com/rust-lang/crates.io-index"
      """

      outdated =
        Cargo.outdated(manifest,
          lockfile: lockfile,
          version_index: %{
            "serde" => ["1.0.198", "1.0.197"],
            "tokio" => ["1.28.2"]
          }
        )

      assert [%{name: "serde", current: "1.0.197", latest: "1.0.198"}] = outdated
    end

    test "selects versions matching common Cargo requirement forms" do
      versions = ["0.2.9", "0.3.0", "1.0.0", "1.2.3", "1.3.0", "2.0.0"]

      assert Cargo.select_version("^1.2.0", versions) == "1.3.0"
      assert Cargo.select_version("~1.2", versions) == "1.2.3"
      assert Cargo.select_version("~1.2.0", versions) == "1.2.3"
      assert Cargo.select_version(">= 1.2.3", versions) == "2.0.0"
      assert Cargo.select_version("0.2", versions) == "0.2.9"
    end

    test "ignores locked versions that do not satisfy the manifest requirement" do
      manifest = Cargo.manifest(dependencies: %{serde: "^1.0"})

      lockfile = """
      [[package]]
      name = "serde"
      version = "2.0.0"
      source = "registry+https://github.com/rust-lang/crates.io-index"

      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "registry+https://github.com/rust-lang/crates.io-index"
      """

      resolved = Cargo.resolve_dependencies(manifest, lockfile: lockfile)

      assert resolved["serde"].locked == "1.0.197"
      assert resolved["serde"].selected == "1.0.197"
      assert resolved["serde"].satisfied?
    end

    test "marks registry dependencies unsatisfied when only incompatible locked versions exist" do
      manifest = Cargo.manifest(dependencies: %{serde: "^1.0"})

      lockfile = """
      [[package]]
      name = "serde"
      version = "2.0.0"
      source = "registry+https://github.com/rust-lang/crates.io-index"
      """

      resolved = Cargo.resolve_dependencies(manifest, lockfile: lockfile)

      assert resolved["serde"].locked == nil
      assert resolved["serde"].selected == nil
      refute resolved["serde"].satisfied?
    end

    test "does not satisfy registry dependencies with git lockfile entries" do
      manifest = Cargo.manifest(dependencies: %{serde: "^1.0"})

      lockfile = """
      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "git+https://github.com/example/serde?rev=abc#abc"
      """

      resolved = Cargo.resolve_dependencies(manifest, lockfile: lockfile)

      assert resolved["serde"].locked == nil
      assert resolved["serde"].selected == nil
      refute resolved["serde"].satisfied?
    end

    test "matches git dependencies by source and requirement" do
      manifest =
        Cargo.manifest(
          dependencies: %{
            serde: %{git: "https://github.com/example/serde", rev: "abc", version: "^1.0"}
          }
        )

      lockfile = """
      [[package]]
      name = "serde"
      version = "2.0.0"
      source = "git+https://github.com/example/serde?rev=abc#abc"

      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "git+https://github.com/example/serde?rev=abc#abc"
      """

      resolved = Cargo.resolve_dependencies(manifest, lockfile: lockfile)

      assert resolved["serde"].locked == "1.0.197"
      assert resolved["serde"].satisfied?
    end
  end

  describe "build integration and cache" do
    test "build plan includes manifest, profile, feature, target, and explicit lock flags" do
      plan =
        Cargo.build_plan(
          manifest_path: "native/Cargo.toml",
          profile: :release,
          target: "x86_64-unknown-linux-gnu",
          features: ["nif", "serde"],
          locked?: true,
          offline?: true
        )

      assert plan.build == [
               "cargo",
               "build",
               "--manifest-path",
               "native/Cargo.toml",
               "--release",
               "--locked",
               "--offline",
               "--target",
               "x86_64-unknown-linux-gnu",
               "--features",
               "nif,serde"
             ]

      assert plan.fetch == [
               "cargo",
               "fetch",
               "--manifest-path",
               "native/Cargo.toml",
               "--locked",
               "--offline"
             ]

      assert plan.test == [
               "cargo",
               "test",
               "--manifest-path",
               "native/Cargo.toml",
               "--release",
               "--locked",
               "--offline",
               "--target",
               "x86_64-unknown-linux-gnu",
               "--features",
               "nif,serde"
             ]
    end

    test "build plan only uses locked mode by default when Cargo.lock exists" do
      tmp_dir = tmp_dir()
      manifest_path = Path.join(tmp_dir, "Cargo.toml")

      File.write!(
        manifest_path,
        "[package]\nname = \"native\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
      )

      unlocked_plan = Cargo.build_plan(manifest_path: manifest_path)
      refute "--locked" in unlocked_plan.build
      refute "--locked" in unlocked_plan.fetch

      File.write!(Path.join(tmp_dir, "Cargo.lock"), "")

      locked_plan = Cargo.build_plan(manifest_path: manifest_path)
      assert "--locked" in locked_plan.build
      assert "--locked" in locked_plan.fetch
      assert "--locked" in locked_plan.test

      override_plan = Cargo.build_plan(manifest_path: manifest_path, locked?: false)
      refute "--locked" in override_plan.build
      refute "--locked" in override_plan.fetch
      refute "--locked" in override_plan.test
    end

    test "auto locked mode resolves relative manifest paths from cd" do
      tmp_dir = tmp_dir()
      native_dir = Path.join(tmp_dir, "native")
      File.mkdir_p!(native_dir)
      File.write!(Path.join(native_dir, "Cargo.toml"), "")
      File.write!(Path.join(native_dir, "Cargo.lock"), "")

      plan = Cargo.build_plan(cd: tmp_dir, manifest_path: "native/Cargo.toml")

      assert "--locked" in plan.build
      assert "--locked" in plan.fetch
      assert "--locked" in plan.test
    end

    test "dry-run build returns the command plan without executing cargo" do
      assert {:ok, %{command: ["cargo", "build" | _]}} =
               Cargo.build(manifest_path: "native/Cargo.toml", dry_run: true)
    end

    test "available? returns a boolean" do
      assert is_boolean(Cargo.available?())
    end

    test "cache plan is stable and changes with dependency state" do
      manifest = Cargo.manifest(name: "cache_test", dependencies: %{serde: "1"})
      same = Cargo.manifest(name: "cache_test", dependencies: %{serde: "1"})
      changed = Cargo.add_dependency(manifest, :tokio, "1")

      assert Cargo.cache_plan(manifest).key == Cargo.cache_plan(same).key
      refute Cargo.cache_plan(manifest).key == Cargo.cache_plan(changed).key

      assert Cargo.cache_plan(manifest).tracked_paths == [
               "priv/rust/Cargo.toml",
               "priv/rust/Cargo.lock",
               "priv/rust/target",
               "priv/rust/.cargo"
             ]
    end

    test "cache plan key changes when git dependency lock source changes without checksums" do
      manifest =
        Cargo.manifest(
          name: "cache_test",
          dependencies: %{
            git_dep: %{git: "https://github.com/example/git_dep", rev: "111", version: "1"}
          }
        )

      first_lock = """
      [[package]]
      name = "git_dep"
      version = "1.0.0"
      source = "git+https://github.com/example/git_dep?rev=111#111"
      """

      second_lock = """
      [[package]]
      name = "git_dep"
      version = "1.0.0"
      source = "git+https://github.com/example/git_dep?rev=222#222"
      """

      refute Cargo.cache_plan(manifest, lockfile: first_lock).key ==
               Cargo.cache_plan(manifest, lockfile: second_lock).key
    end

    test "cache plan key changes when registry checksum changes" do
      manifest = Cargo.manifest(name: "cache_test", dependencies: %{serde: "1"})

      first_lock = """
      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "registry+https://github.com/rust-lang/crates.io-index"
      checksum = "abc"
      """

      second_lock = """
      [[package]]
      name = "serde"
      version = "1.0.197"
      source = "registry+https://github.com/rust-lang/crates.io-index"
      checksum = "def"
      """

      refute Cargo.cache_plan(manifest, lockfile: first_lock).key ==
               Cargo.cache_plan(manifest, lockfile: second_lock).key
    end

    test "prepare_cache creates the planned cache directory" do
      tmp_dir = tmp_dir()
      manifest = Cargo.manifest(name: "cache_dir", dependencies: %{serde: "1"})

      assert {:ok, plan} = Cargo.prepare_cache(manifest, cache_root: tmp_dir)
      assert File.dir?(plan.directory)
    end
  end

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "lux_cargo_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)
    path
  end
end
