# Lux Rust Core (`lux_core`)

Native Rust integration for [Lux](https://github.com/Spectral-Finance/lux).

This crate provides:

- Memory-safe Erlang NIF bindings via [Rustler](https://github.com/rusterlium/rustler)
- Bidirectional type conversion between Elixir terms and Rust values
- An error type that propagates to `{:error, reason}` on the Elixir side
- Dirty-CPU NIFs for compute-heavy work so the BEAM scheduler is not blocked

## Layout

```
priv/rust/
├── Cargo.toml
├── README.md
└── src/
    ├── lib.rs      # NIF entrypoints
    ├── types.rs    # Elixir ↔ Rust conversion
    └── error.rs    # Error type and NIF encoding
```

The Elixir API lives in `Lux.Rust` (`lib/lux/rust.ex`) and loads this crate
from `priv/rust` through `Lux.Rust.Native`.

## Build

From `lux/`:

```bash
mix deps.get
mix compile
```

Rustler compiles this crate and places the shared library under `priv/native/`.

Standalone (requires Erlang headers on `ERL_EI_INCLUDE_DIR` / a loaded Mix project):

```bash
mix compile
# or, after mix has configured the environment:
cargo build --release --manifest-path priv/rust/Cargo.toml
```

## Safety

- No raw pointers are passed across the FFI boundary.
- Binaries and strings are copied into owned Rust buffers (`Vec<u8>`, `String`).
- Invalid UTF-8 binaries are surfaced as `{:error, {:conversion, _}}` rather than panicking.
- Panics inside NIFs are caught by Rustler and returned as errors; they do not crash the BEAM.
- Long-running work uses `schedule = "DirtyCpu"`.
