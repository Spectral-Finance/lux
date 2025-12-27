# Lux Rust NIF

Native Rust integration for the Lux framework, providing high-performance code execution via NIFs (Native Implemented Functions).

## Overview

This crate provides FFI bindings between Elixir and Rust using [Rustler](https://github.com/rusterlium/rustler). It enables:

- **Type-safe conversions** between Elixir and Rust types
- **Error propagation** with proper Elixir exception handling
- **Memory-safe interop** via Rustler's safety guarantees
- **High-performance execution** directly in the BEAM VM

## Building

```bash
# Development build
cargo build

# Release build (optimized)
cargo build --release
```

The compiled library will be at `target/release/liblux_rust.so` (Linux), `liblux_rust.dylib` (macOS), or `lux_rust.dll` (Windows).

## Project Structure

```
priv/rust/
├── Cargo.toml          # Rust package manifest
├── README.md           # This file
└── src/
    ├── lib.rs          # Main NIF entry points and function dispatch
    ├── error.rs        # Error types for Rust-Elixir interop
    └── types.rs        # Type definitions for value conversion
```

## NIF Functions

### `execute(func_name, args)`

Execute a named function with the given arguments.

**Arguments:**
- `func_name`: String - Name of the function to call
- `args`: Map - Arguments to pass to the function

**Returns:** `{:ok, result}` or `{:error, message}`

### `eval(expression, variables)`

Evaluate a simple expression with optional variables.

**Arguments:**
- `expression`: String - The expression to evaluate
- `variables`: Map - Variable bindings

**Returns:** `{:ok, result}` or `{:error, message}`

### `version()`

Get version information about the Rust integration.

**Returns:** Map with `version`, `rustc`, and `target` keys

### `health_check()`

Check if the NIF is functional.

**Returns:** `{:ok, "healthy"}` or `{:error, reason}`

## Built-in Functions

| Function | Arguments | Description |
|----------|-----------|-------------|
| `add` | `%{a: number, b: number}` | Add two numbers |
| `multiply` | `%{a: number, b: number}` | Multiply two numbers |
| `concat` | `%{a: string, b: string}` | Concatenate strings |
| `hash_sha256` | `%{data: string \| binary}` | SHA256 hash |
| `json_parse` | `%{json: string}` | Parse JSON string |
| `json_stringify` | `%{value: any}` | Stringify to JSON |

## Adding New Functions

1. Add a match arm in `dispatch_function()`:

```rust
fn dispatch_function<'a>(...) -> RustResult<Term<'a>> {
    match func_name {
        // existing functions...
        "my_function" => my_function(env, args),
        _ => Err(RustError::UnknownFunction(...)),
    }
}
```

2. Implement the function:

```rust
fn my_function<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;

    // Get arguments
    let input = map.get("input")
        .ok_or_else(|| RustError::MissingArgument("input".to_string()))?;

    // Process
    let result = // ...

    Ok(encode_value(env, &result))
}
```

3. Rebuild: `cargo build --release`

## Type Mapping

| Elixir Type | Rust Type (`RustValue`) |
|-------------|------------------------|
| `nil` | `Nil` |
| `true`/`false` | `Boolean(bool)` |
| `integer` | `Integer(i64)` |
| `float` | `Float(f64)` |
| `binary`/`string` | `String(String)` |
| `binary` (non-UTF8) | `Binary(Vec<u8>)` |
| `atom` | `Atom(String)` |
| `list` | `List(Vec<RustValue>)` |
| `map` | `Map(HashMap<String, RustValue>)` |
| `tuple` | `Tuple(Vec<RustValue>)` |

## Error Types

Errors are defined in `error.rs`:

- `UnknownFunction` - Function not in dispatch table
- `MissingArgument` - Required argument not provided
- `TypeMismatch` - Wrong type for operation
- `DivisionByZero` - Division by zero attempted
- `UndefinedVariable` - Variable not in scope
- `DecodingError` - Failed to decode Elixir term
- `EncodingError` - Failed to encode Rust value
- `JsonError` - JSON parse/stringify error
- `ExecutionError` - Generic execution failure

## Testing

Run Rust tests:

```bash
cargo test
```

Run Elixir tests (from project root):

```bash
mix test test/lux/rust_test.exs
```

## Dependencies

- `rustler` - Elixir NIF bindings
- `serde` / `serde_json` - JSON serialization
- `thiserror` - Error type derivation

## License

MIT License - See the project root LICENSE file.
