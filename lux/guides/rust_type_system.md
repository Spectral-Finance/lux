# Rust Type System and Serde Serialization in Lux

`Lux.Rust.TypeSystem` provides bidirectional type mapping, custom struct/enum definitions, and Serde-compatible serialization between Elixir and Rust (`Spectral-Finance/lux#101`).

## Core Features

1. **Primitive & Generic Type Mapping**:
   - Maps Elixir primitives (`:i64`, `:u64`, `:f64`, `:bool`, `:string`) and compound types (`{:vec, t}`, `{:option, t}`, `{:result, ok, err}`, `{:hashmap, k, v}`, `{:tuple, [...]}`) directly to Rust signatures.
2. **Custom Struct & Enum Definitions**:
   - Define strongly-typed structs via `Lux.Rust.TypeSystem.define_struct/4` and tagged enums via `Lux.Rust.TypeSystem.define_enum/4`.
3. **Serde Code Generation**:
   - Automatically generate Rust structs and enums annotated with `#[derive(Serialize, Deserialize)]` via `generate_serde_rust_code/1`.
4. **Bidirectional Conversion**:
   - Convert nested Elixir structures to Serde JSON payloads via `to_rust_payload/2` and deserialize back via `from_rust_payload/2`.
