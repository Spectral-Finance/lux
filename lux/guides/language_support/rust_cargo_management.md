# Rust & Cargo Package Management in Lux

This guide covers managing Rust crates, dependencies, and build workflows within the Lux multi-agent framework.

## Features
- **Manifest Generation**: Programmatically construct, serialize, and parse `Cargo.toml`.
- **Dependency Management**: Add, update, and resolve crate dependencies dynamically.
- **Build Integration**: Execute `cargo build --release`, `cargo test`, and `cargo check`.
- **Safe Package Caching**: Configure and warm isolated `CARGO_HOME` caches per agent process.

## Quick Example
```elixir
alias Lux.Rust.Cargo

# 1. Initialize a new Cargo manifest
manifest = Cargo.new_manifest("my_agent_module", version: "0.1.0")

# 2. Add dependencies
{:ok, manifest} = Cargo.add_dependency(manifest, "serde", "1.0")
{:ok, manifest} = Cargo.add_dependency(manifest, "tokio", %{version: "1.30", features: ["full"]})

# 3. Serialize to TOML
toml_content = Cargo.to_toml(manifest)
File.write!("Cargo.toml", toml_content)

# 4. Build or test native module
{:ok, build_output} = Cargo.build(".", release: true)
```
