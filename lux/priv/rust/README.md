# Lux Rust Components

This directory contains the Rust NIF (Native Implemented Functions) components of the Lux framework. It provides high-performance native code execution for compute-intensive tasks.

## Development Setup

```bash
# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build the NIF
cargo build --release
```

## Running Tests

```bash
cargo test
```

## Building

```bash
# Release build (optimized)
cargo build --release

# Debug build
cargo build
```

## Integration with Elixir

The NIF is automatically loaded when `Lux.Rust` module is used. Functions available:

- `Lux.Rust.eval/2` - Evaluate simple expressions
- `Lux.Rust.to_json/1` - Convert Elixir terms to JSON
- `Lux.Rust.from_json/1` - Parse JSON to Elixir terms
- `Lux.Rust.version/0` - Get Rust integration version
- `Lux.Rust.health_check/0` - Verify NIF is loaded correctly
