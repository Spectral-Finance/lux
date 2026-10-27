defmodule Lux.Rust.CargoTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Cargo

  describe "generate_manifest/1 and parse_manifest/1" do
    test "generates valid Cargo.toml and round-trips through parse_manifest/1" do
      toml =
        Cargo.generate_manifest(%{
          name: "lux_solana_signer",
          version: "0.2.1",
          edition: "2021",
          description: "Solana signing component for Lux",
          license: "MIT",
          authors: ["Lux Team"],
          lib: %{name: "lux_solana_signer", crate_type: ["cdylib", "rlib"]},
          dependencies: %{
            "serde" => %{version: "1.0", features: ["derive"]},
            "tokio" => %{version: "1.38.0", default_features: false, features: ["rt", "macros"]},
            "anyhow" => "1.0.86"
          },
          dev_dependencies: %{
            "criterion" => "0.5"
          }
        })

      assert toml =~ ~s(name = "lux_solana_signer")
      assert toml =~ ~s(crate-type = ["cdylib", "rlib"])
      assert toml =~ ~s(anyhow = "1.0.86")
      assert toml =~ ~s(serde = { version = "1.0", features = ["derive"] })

      assert {:ok, parsed} = Cargo.parse_manifest(toml)
      assert parsed.package.name == "lux_solana_signer"
      assert parsed.package.version == "0.2.1"
      assert parsed.dependencies["serde"].version == "1.0"
      assert parsed.dependencies["serde"].features == ["derive"]
      assert parsed.dependencies["tokio"].default_features == false
      assert parsed.dev_dependencies["criterion"].version == "0.5"
    end
  end

  describe "put_dependency/4 and remove_dependency/3" do
    test "adds, updates, and removes dependencies with validation" do
      {:ok, manifest} =
        Cargo.generate_manifest(%{name: "demo_crate", version: "0.1.0"})
        |> Cargo.parse_manifest()

      assert {:ok, updated} =
               Cargo.put_dependency(manifest, "reqwest", %{
                 version: "^0.12.0",
                 features: ["json", "rustls-tls"]
               })

      assert updated.dependencies["reqwest"].features == ["json", "rustls-tls"]

      removed = Cargo.remove_dependency(updated, "reqwest")
      refute Map.has_key?(removed.dependencies, "reqwest")

      assert {:error, {:invalid_version_requirement, "not_a_version"}} =
               Cargo.put_dependency(manifest, "bad", "not_a_version")
    end
  end

  describe "version_compatible?/2 and resolve_dependencies/2" do
    test "validates Cargo caret, tilde, exact, and wildcard requirements" do
      assert Cargo.version_compatible?("1.0.197", "1.0")
      assert Cargo.version_compatible?("1.4.2", "^1.2.0")
      refute Cargo.version_compatible?("2.0.0", "^1.2.0")
      assert Cargo.version_compatible?("1.2.9", "~1.2.3")
      refute Cargo.version_compatible?("1.3.0", "~1.2.3")
      assert Cargo.version_compatible?("0.5.0", "=0.5.0")
    end

    test "resolves dependencies against a registry catalog and catches conflicts" do
      deps = %{
        "serde" => %{version: "^1.0.180", features: ["derive"]},
        "bincode" => "1.3.3"
      }

      registry = %{
        "serde" => ["1.0.204", "1.0.190", "0.9.0"],
        "bincode" => ["1.3.3"]
      }

      assert {:ok, resolved} = Cargo.resolve_dependencies(deps, registry)
      assert Enum.find(resolved, &(&1.name == "serde")).version == "1.0.204"

      bad_registry = %{"serde" => ["0.8.0"]}
      assert {:error, {"serde", {:no_matching_version, "^1.0.180", ["0.8.0"]}}} =
               Cargo.resolve_dependencies(deps, bad_registry)
    end
  end

  describe "cache_key/2, fetch_or_store_cache/3, and prepare_project/3" do
    test "produces deterministic cache keys, caches artifacts on disk, and scaffolds crate" do
      tmp_dir = Path.join(System.tmp_dir!(), "lux_cargo_test_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf(tmp_dir) end)

      cfg = %{
        name: "cached_crate",
        version: "0.1.0",
        dependencies: %{"serde" => %{version: "1.0", features: ["derive"]}}
      }

      assert {:ok, project} = Cargo.prepare_project(tmp_dir, cfg, profile: :release, features: ["simd"])
      assert File.regular?(project.manifest_path)
      assert File.regular?(Path.join([tmp_dir, "src", "lib.rs"]))
      assert {"cargo", ["build", "--manifest-path", _, "--release", "--features", "simd"]} = project.command

      cache_dir = Path.join(tmp_dir, ".cache")

      assert {:ok, %{artifact: "libcached_crate.so"}, :miss} =
               Cargo.fetch_or_store_cache(cache_dir, project.cache_key, fn ->
                 {:ok, %{artifact: "libcached_crate.so"}}
               end)

      assert {:ok, %{artifact: "libcached_crate.so"}, :hit} =
               Cargo.fetch_or_store_cache(cache_dir, project.cache_key, fn ->
                 flunk("builder should not run on cache hit")
               end)
    end
  end
end
