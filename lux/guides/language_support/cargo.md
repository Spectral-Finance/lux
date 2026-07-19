# Cargo Package Management (Rust)

Lux provides Cargo package-management integration for the upcoming Rust
language support. The `Lux.Cargo` module lets you generate and parse
`Cargo.toml` manifests, manage dependencies and versions, drive the Rust build
pipeline through the `cargo` CLI, and cache resolved packages.

Manifest parsing and generation are pure functions and require no Rust
toolchain. Build and resolution helpers shell out to `cargo`, so they require
`cargo`/`rustc` to be installed on the host.

## Managing a Manifest

```elixir
manifest =
  "my_agent"
  |> Lux.Cargo.new_manifest("0.1.0")
  |> Lux.Cargo.add_dependency("serde", "1.0")
  |> Lux.Cargo.add_dependency("tokio", "1.35")

Lux.Cargo.get_dependency(manifest, "serde")
# => "1.0"
```

## Adding Dependencies

Dependencies are added by name and version requirement. Adding the same name
again updates the version:

```elixir
manifest = Lux.Cargo.add_dependency(manifest, "serde", "1.0.195")
manifest = Lux.Cargo.remove_dependency(manifest, "tokio")
```

## Generating and Parsing `Cargo.toml`

```elixir
toml = Lux.Cargo.to_toml(manifest)
# [package]
# name = "my_agent"
# version = "0.1.0"
# edition = "2021"
#
# [dependencies]
# serde = "1.0.195"

{:ok, manifest} = Lux.Cargo.from_toml(toml)
```

You can also work directly with files:

```elixir
:ok = Lux.Cargo.write_manifest(manifest, "rust/Cargo.toml")
{:ok, manifest} = Lux.Cargo.read_manifest("rust/Cargo.toml")
```

## Resolving Dependencies and Building

```elixir
# Fetch dependencies described by Cargo.toml
{:ok, _output} = Lux.Cargo.resolve(cwd: "rust")

# Build (debug or release)
{:ok, _output} = Lux.Cargo.build(cwd: "rust")
{:ok, _output} = Lux.Cargo.build(cwd: "rust", release: true)
```

When `cargo` is not installed these functions return
`{:error, "cargo executable not found on host"}`.

## Package Caching

Resolved package versions can be cached to avoid re-resolving:

```elixir
:ok = Lux.Cargo.cache_package("serde", "1.0.195")
Lux.Cargo.cached_package("serde")
# => "1.0.195"

Lux.Cargo.clear_cache()
```

The cache lives under `Lux.Cargo.cache_dir/0`.
