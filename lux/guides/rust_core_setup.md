# Rust Core Integration Setup (`priv/rust`)

Lux provides a memory-safe Rust core runtime in `priv/rust` (`lux_core_nif`) paired with `Lux.Rust.Core`.

## Features
- **Cargo Workspace in `priv/rust`**: Configured for both `cdylib` NIF shared libraries and `rlib` unit testing.
- **Bidirectional Type Conversion**: Safe conversion between Elixir integers (`i64`), floats (`f64`), booleans, UTF-8 strings, raw byte buffers, lists, and maps.
- **Structured Error Propagation**: `Lux.Rust.Core.FfiError` carries machine-readable error codes and recoverability flags.
- **Memory Safety Guarantees**: Enforces payload byte limits (`max_bytes`) and i64 numeric range checks before crossing the FFI boundary.
