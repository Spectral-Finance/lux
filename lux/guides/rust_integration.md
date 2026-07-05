# Rust Integration in Lux

Lux provides high-performance native code execution and FFI bindings through core Rust integration using [Rustler](https://github.com/rusterlium/rustler).

## Overview

The Rust integration enables you to write computationally intensive operations and low-level system integrations in Rust while leveraging Elixir for orchestration and high-level logic.

## Project Structure

The Rust code lives within the `priv/rust/lux_core` directory of the Lux library. 
It follows standard Cargo project conventions.

## Type Conversion and FFI

Lux automatically maps basic types between Elixir and Rust using Rustler's type conversion capabilities.

### Example Usage

The `Lux.RustCore` module exposes the NIF (Native Implemented Function) bindings:

```elixir
# Basic integer addition with memory safety and overflow protection
iex> Lux.RustCore.add(5, 10)
15

# Working with Strings and complex task propagation
iex> Lux.RustCore.compute_complex_task("analyze this")
{:ok, "Processed: analyze this"}

# Error Handling example
iex> Lux.RustCore.compute_complex_task("")
{:error, "Type conversion error: Data cannot be empty"}
```

## Error Handling

Lux provides a structured error handling framework in Rust through the `LuxError` type, ensuring that native panics or logical errors propagate smoothly back to Elixir as standard `{:error, reason}` tuples or safely raised exceptions.

```rust
pub enum LuxError {
    TypeConversion(String),
    MemorySafety(String),
}
```

This guarantees safety and consistency across the language boundaries.
