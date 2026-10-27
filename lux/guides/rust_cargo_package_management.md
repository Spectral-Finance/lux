# Rust Cargo Package Management in Lux

`Lux.Rust.Cargo` provides `Cargo.toml` manifest generation and parsing, dependency resolution, semantic version compatibility checks, build pipeline command integration, and deterministic package caching for Rust components in Lux.

## Generating a `Cargo.toml` Manifest and Adding Dependencies

```elixir
manifest_toml =
  Lux.Rust.Cargo.generate_manifest(%{
    name: "lux_crypto_worker",
    version: "0.1.0",
    edition: "2021",
    lib: %{crate_type: ["cdylib", "rlib"]},
    dependencies: %{
      "serde" => %{version: "1.0", features: ["derive"]},
      "tokio" => %{version: "1.38.0", features: ["rt", "macros"]},
      "sha2" => "0.10"
    }
  })

{:ok, manifest} = Lux.Rust.Cargo.parse_manifest(manifest_toml)
{:ok, manifest} = Lux.Rust.Cargo.put_dependency(manifest, "hex", "0.4.3")
```

## Dependency Resolution & Version Management

```elixir
{:ok, resolved} =
  Lux.Rust.Cargo.resolve_dependencies(manifest.dependencies, %{
    "serde" => ["1.0.210", "1.0.197"],
    "tokio" => ["1.38.0"],
    "sha2" => ["0.10.8"],
    "hex" => ["0.4.3"]
  })
```

## Build System Integration & Package Caching

```elixir
{:ok, project} =
  Lux.Rust.Cargo.prepare_project("/tmp/lux_crypto_worker", %{
    name: "lux_crypto_worker",
    version: "0.1.0",
    dependencies: %{"serde" => %{version: "1.0", features: ["derive"]}}
  }, profile: :release)
```
