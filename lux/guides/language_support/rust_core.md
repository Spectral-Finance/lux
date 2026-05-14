# Rust Core Integration

Lux includes a first Rust core bridge under `priv/rust/lux_core`. The bridge is
intentionally small: it uses a Cargo crate and a JSON/base64 command boundary so
Rust execution, primitive type conversion, and explicit error propagation are
available without tying the framework to a specific NIF strategy too early.

## Project Layout

```text
priv/rust/lux_core/
  Cargo.toml
  src/lib.rs
  src/main.rs
```

`src/lib.rs` contains native operations. `src/main.rs` is a thin command bridge
used by `Lux.Rust.Core`.

## Running Native Operations

```elixir
Lux.Rust.Core.execute(:echo, %{"name" => "lux"})
Lux.Rust.Core.type_of([1, 2, 3])
Lux.Rust.Core.sum_i64([4, 5, 6])
```

The Elixir bridge encodes JSON-compatible values as base64 JSON and invokes:

```bash
cargo run --quiet --manifest-path priv/rust/lux_core/Cargo.toml -- <operation> <base64-json>
```

The Rust bridge responds with either:

```json
{"ok": true, "value": {"sum": 15}}
```

or:

```json
{"ok": false, "error": {"code": "type_error", "message": "expected integer"}}
```

## Supported Operations

- `echo` returns the input value unchanged.
- `type_of` returns `null`, `boolean`, `integer`, `float`, `string`, `array`, or
  `object`.
- `sum_i64` sums an array of signed 64-bit integers and reports overflow.
- `is_truthy` applies Rust-side truthiness checks for smoke testing.

## Why A Command Bridge First

This establishes a real Rust project, build path, conversion boundary, and error
contract while keeping the runtime safe for existing Lux installations. Future
work can replace the command boundary with Rustler/NIF bindings while preserving
the same operation and error contracts.
