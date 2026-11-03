# Lux Core Rust Runtime (`lux_rust`)

High-performance native code execution runtime and FFI type conversion bridge for the Lux agent framework.

## Project Structure
- `src/lib.rs`: Entrypoint and JSON IPC interface.
- `src/types.rs`: Type conversion mappings between Elixir terms/JSON values and Rust data structures (`LuxValue`, `FromLuxValue`, `ToLuxValue`).
- `src/error.rs`: Structured error hierarchy (`RustError`) with panic isolation.
- `src/bridge.rs`: Function registry and panic-safe execution dispatcher.

## Building
```bash
cargo build --release
```

## Running Tests
```bash
cargo test
```
