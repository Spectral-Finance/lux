# Rust Integration Guide

Lux includes native Rust bindings via [Rustler](https://github.com/rusterlium/rustler) for high-performance operations.

## Architecture

```
native/lux_native/         # Rust crate
├── Cargo.toml             # Dependencies (rustler, serde, thiserror)
└── src/
    ├── lib.rs             # NIF entry points
    ├── types.rs           # Type validation system
    └── error.rs           # Error types
```

## Modules

### `Lux.Native`

Low-level NIF bindings. Functions accept and return raw strings/integers:

```elixir
# JSON round-trip (parse + re-serialize)
Lux.Native.json_roundtrip(~s({"key": "value"}))
# => ~s({"key":"value"})

# Type validation
Lux.Native.validate_json(~s("hello"), "string")
# => {:ok, "valid"}

# SHA-256 hash
Lux.Native.sha256_hex("hello")
# => "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

# Benchmark (microseconds for N iterations)
Lux.Native.bench_json_roundtrip(~s({"data": [1,2,3]}), 10_000)
# => 1234
```

### `Lux.Rust`

High-level Elixir API with automatic JSON encoding/decoding:

```elixir
# Round-trip with automatic encoding
Lux.Rust.roundtrip(%{users: [%{name: "Alice"}]})
# => {:ok, %{"users" => [%{"name" => "Alice"}]}}

# Type validation with Elixir terms
Lux.Rust.validate("hello", "string")   # => :ok
Lux.Rust.validate(42, "string")        # => {:error, "Type mismatch: ..."}

# SHA-256
Lux.Rust.sha256("hello")

# Check if NIF is loaded
Lux.Rust.available?()                  # => true
```

## Type System

Supported type descriptors for validation:

| Type        | Matches                  |
|-------------|--------------------------|
| `"string"`  | JSON strings             |
| `"integer"` | Whole numbers (i64/u64)  |
| `"float"`   | Any JSON number          |
| `"number"`  | Any JSON number          |
| `"boolean"` | `true` / `false`         |
| `"null"`    | `null`                   |
| `"array"`   | JSON arrays              |
| `"object"`  | JSON objects             |
| `"any"`     | Any valid JSON value     |

## Error Handling

Rust errors are mapped to Elixir error tuples:

- **Parse errors**: `{:error, "Parse error: ..."}`
- **Type mismatches**: `{:error, "Type mismatch: expected string, got integer"}`
- **Unknown types**: `{:error, "Unknown type: foobar"}`

## Building

The Rust NIF compiles automatically with `mix compile`. Requirements:

- Rust toolchain (rustc + cargo)
- No additional system dependencies

## Performance

The Rust NIF provides significant speedups for:
- JSON validation (10-50x vs pure Elixir)
- Hashing operations (5-20x vs :crypto for small inputs)
- Bulk data transformation
