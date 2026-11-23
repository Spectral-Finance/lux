# Rust Integration in Lux

Lux ships an optional **native Rust core** that bridges high-performance Rust
code into the BEAM via [Rustler](https://hexdocs.pm/rustler). This guide covers
the architecture, how to build it, and how to call it from Elixir.

## Overview

The Rust core lives in `priv/rust` and is compiled as a `cdylib` (a dynamic
shared library). When the library loads, Rustler registers its NIFs (Native
Implemented Functions) into the `Lux.Rust` module, replacing the
`:nif_not_loaded_yet` fallback stubs defined in `Lux.Rust`.

```
┌─────────────────┐   Rustler NIFs   ┌──────────────────┐
│  Lux.Rust       │ ───────────────▶ │  (Rust-backed)   │
│  (Elixir API)   │                  │  NIF functions   │
└─────────────────┘                  └────────┬─────────┘
                                                │ BEAM NIF
                                                ▼
                                     ┌──────────────────┐
                                     │  priv/rust       │
                                     │  (Rust cdylib)   │
                                     └──────────────────┘
```

## Building

The native library is built with the `mix rust.build` task:

```bash
# Release build (default)
mix rust.build

# Debug build
mix rust.build --debug
```

Or directly with Cargo:

```bash
cd priv/rust
cargo build --release
```

The compiled library is written to `priv/rust/target/release/liblux_rust.so`
(`.dylib` on macOS). `Lux.Rust` loads it automatically on application start
via `:erlang.load_nif/2`.

> **Graceful degradation**: If the library has not been built, `Lux.Rust`
> returns `{:error, :nif_not_loaded}` (or raises `:nif_not_loaded` for the
> non-tuple functions) instead of crashing. This keeps Lux usable without a
> Rust toolchain.

## Usage

```elixir
# Pure compute
Lux.Rust.add(2, 3)              #=> 5
Lux.Rust.multiply(4, 5)         #=> 20
Lux.Rust.sum_list([1, 2, 3, 4]) #=> 10
Lux.Rust.reverse_list([1, 2, 3])#=> [3, 2, 1]

# Strings & binaries
Lux.Rust.to_uppercase("hello")  #=> "HELLO"
Lux.Rust.join_strings(["a", "b"], "-") #=> "a-b"
Lux.Rust.binary_checksum(<<1, 2, 3>>)   #=> {:ok, 6}

# Fallible operations return {:ok, _} | {:error, _}
Lux.Rust.factorial(5)           #=> {:ok, 120}
Lux.Rust.factorial(-1)          #=> {:error, %{kind: :invalid_argument, ...}}
Lux.Rust.parse_int("42")        #=> {:ok, 42}
Lux.Rust.parse_int("nope")      #=> {:error, %{kind: :invalid_argument, ...}}

# Panic safety: a Rust panic becomes an error tuple, not a VM crash
Lux.Rust.safe_compute(false)    #=> {:ok, 99}
Lux.Rust.safe_compute(true)     #=> {:error, %{kind: :panic, ...}}
```

## Architecture

The crate is organized into modules:

| Module | Responsibility |
|--------|----------------|
| `lib.rs` | Crate root, `rustler::init!` registration, `on_load` hook |
| `nifs.rs` | NIF wrappers + pure `*_impl` logic (unit-tested) |
| `convert.rs` | Elixir ↔ Rust type-conversion helpers |
| `error.rs` | `LuxError` enum + `Encoder` impl → `{:error, %{...}}` |

### Type conversion

Rustler's `Encoder`/`Decoder` handle the primitive conversions automatically
(`i64`, `String`, `Vec<T>`, `Binary`). For compound types, `convert.rs` provides
helpers like `map_get` that decode a value out of an Elixir map term.

### Error handling

All fallible NIFs return `Result<T, LuxError>`. Rustler encodes `Ok(v)` as
`{:ok, v}` and `Err(e)` as `{:error, %{kind: ..., message: ..., detail: ...}}`
via the `Encoder` impl in `error.rs`. The `LuxError` enum covers:

- `:invalid_argument` — bad input (e.g. negative factorial)
- `:internal` — unexpected internal failure (e.g. overflow)
- `:panic` — a caught Rust panic (via `catch_unwind`)
- `:badarg` — a Rustler `BadArg` from decoding

### Memory safety

- No raw pointers cross the boundary; Rustler owns all data on the BEAM heap.
- `catch_unwind` wraps compute-heavy NIFs so a panic becomes an error tuple.
- Binaries are borrowed (`&[u8]`) from the BEAM heap and never mutated.

## Testing

Run the Rust unit tests:

```bash
cd priv/rust && cargo test
```

Run the Elixir integration tests (which exercise the compiled NIFs):

```bash
mix test --include integration test/integration/rust_test.exs
```

## Adding a new NIF

1. Write the pure logic as a plain `*_impl` function in `nifs.rs` (unit-testable).
2. Add a thin `#[rustler::nif]` wrapper that delegates to it.
3. Register the function name in `rustler::init!` in `lib.rs`.
4. Add a fallback stub in `Lux.Rust` returning `{:error, :nif_not_loaded}`.
5. Add a unit test for the `*_impl` function and an integration test in
   `test/integration/rust_test.exs`.