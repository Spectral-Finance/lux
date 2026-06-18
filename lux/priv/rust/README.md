# Lux Rust Runtime

This directory contains Rust/Cargo support for the Lux agent framework.

## Prerequisites

- Rust toolchain (install via [rustup](https://rustup.rs/))
- Cargo (included with Rust)

## Usage

```bash
# Build the Rust project
mix cargo build

# Run tests
mix cargo test

# Check compilation
mix cargo check
```

## Adding Dependencies

Use the `Lux.Lenses.Cargo.Lens` lens to manage dependencies:

```elixir
Lux.Lenses.Cargo.Lens.focus(%{action: "add_dependency", name: "serde", version: "1.0"})
```

Or edit `Cargo.toml` directly.
