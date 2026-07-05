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

## Rust Components (Prisms & Beams)

Lux supports implementing high-performance native components (Prisms and Beams) directly in Rust, with full framework integration. This is facilitated by the `Component` trait, which provides lifecycle management and `async`/`await` support out of the box using `tokio`.

### The Component Trait

The core of Rust component definition is the `Component` trait, which defines the standard lifecycle:

```rust
use async_trait::async_trait;

#[async_trait]
pub trait Component {
    type Input;
    type Output;

    async fn init(&mut self) -> Result<(), ComponentError> { Ok(()) }
    async fn execute(&self, input: Self::Input) -> Result<Self::Output, ComponentError>;
    async fn terminate(&mut self) -> Result<(), ComponentError> { Ok(()) }
}
```

### Example: Rust Math Prism

You can define a Rust component for computationally heavy operations, such as mathematical calculations or data processing.

```rust
use async_trait::async_trait;
use crate::components::{Component, ComponentError};

pub struct MathPrism;

#[async_trait]
impl Component for MathPrism {
    type Input = (i64, i64);
    type Output = i64;

    async fn execute(&self, input: Self::Input) -> Result<Self::Output, ComponentError> {
        let (a, b) = input;
        a.checked_add(b)
            .ok_or_else(|| ComponentError::Execution("Integer overflow".to_string()))
    }
}
```

### Elixir Integration

These Rust components can then be seamlessly executed from Elixir using Rustler NIFs. We can use dirty schedulers for performance optimizations:

```elixir
iex> Lux.RustCore.execute_math_prism(10, 20)
{:ok, 30}
```
