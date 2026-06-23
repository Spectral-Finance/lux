# Rust Integration

Lux provides a robust, native integration with Rust via [Rustler](https://github.com/rusterlium/rustler). This allows developers to write high-performance native code and integrate it seamlessly with Elixir-based Lux Agents, Beams, and Prisms.

## Project Structure

The core Rust integration is structured as a Cargo workspace located at `priv/rust/lux_core`. This directory contains the Rust crate that exposes the NIF (Native Implemented Function) bindings to Elixir.

- `priv/rust/lux_core/src/lib.rs` - The Rust code exposing NIFs.
- `lib/lux/rust/core.ex` - The Elixir module (`Lux.Rust.Core`) that loads the Rustler library.

## Type Conversion and FFI

By using Rustler, Lux natively supports encoding and decoding of primitive types (Integers, Floats, Strings, Lists, Maps, and Binaries).

### Example: Basic Native Math

```elixir
# lib/lux/rust/core.ex
defmodule Lux.Rust.Core do
  use Rustler, otp_app: :lux, crate: :lux_core, path: "priv/rust/lux_core"
  
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
```

On the Rust side (`priv/rust/lux_core/src/lib.rs`):

```rust
#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}
```

In Elixir, this can be seamlessly called:

```elixir
iex> Lux.Rust.Core.add(10, 20)
30
```

## Error Handling Framework

Lux's Rust integration mandates safe error propagation. Rust panics are isolated where possible, but proper error handling involves returning idiomatic Elixir `{:ok, result}` or `{:error, reason}` tuples.

### Example: Safe Division

```rust
#[rustler::nif]
fn safe_divide<'a>(env: Env<'a>, a: f64, b: f64) -> (rustler::Atom, Term<'a>) {
    if b == 0.0 {
        (atoms::error(), atoms::division_by_zero().encode(env))
    } else {
        (atoms::ok(), (a / b).encode(env))
    }
}
```

In Elixir:

```elixir
iex> Lux.Rust.Core.safe_divide(10.0, 2.0)
{:ok, 5.0}

iex> Lux.Rust.Core.safe_divide(10.0, 0.0)
{:error, :division_by_zero}
```

## Memory Safe Buffer Processing

When dealing with large payloads (e.g., embeddings, cryptographic keys), memory safety is paramount. Rustler provides zero-copy abstractions for binaries where possible, or owned binaries for safe manipulation.

```rust
#[rustler::nif]
fn reverse_bytes<'a>(env: Env<'a>, binary: rustler::Binary<'a>) -> (rustler::Atom, Term<'a>) {
    let mut reversed: Vec<u8> = binary.as_slice().to_vec();
    reversed.reverse();
    
    match rustler::OwnedBinary::new(reversed.len()) {
        Some(mut erl_bin) => {
            erl_bin.as_mut_slice().copy_from_slice(&reversed);
            (atoms::ok(), erl_bin.release(env).encode(env))
        }
        None => (atoms::error(), atoms::allocation_failed().encode(env)),
    }
}
```

## Running the Tests

To test the Rust integration locally, run:

```bash
mix test test/unit/lux/rust/core_test.exs
```

This will automatically trigger `cargo build` through the Rustler compiler hook.
