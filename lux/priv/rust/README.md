# Lux Rust Core

Native Rust core for the [Lux](https://github.com/Spectral-Finance/lux) agent
framework. This crate is compiled as a `cdylib` and loaded into the BEAM as a
[Rustler](https://github.com/rusterlium/rustler) NIF, exposing high-performance,
memory-safe native functions to Elixir through the `Lux.Rust` module.

## Layout

| File | Responsibility |
|------|----------------|
| `src/lib.rs` | Crate root, `rustler::init!` registration, `on_load` hook |
| `src/nifs.rs` | NIF wrappers + pure `*_impl` logic (unit-tested) |
| `src/convert.rs` | Elixir ↔ Rust type-conversion helpers |
| `src/error.rs` | `LuxError` enum + `Encoder` impl → `{:error, %{...}}` |

## Building

From the repository root:

```bash
cargo build --release      # build the cdylib
cargo test                 # run the Rust unit tests
```

Or via the Mix task (from the `lux/` directory):

```bash
mix rust.build             # release build
mix rust.build --debug     # debug build
```

The compiled library is written to `target/release/liblux_rust.so` (`.dylib` on
macOS, `.dll` on Windows). `Lux.Rust` loads it automatically on module load via
`:erlang.load_nif/2`.

## Design

- **Memory safety** — every boundary crossing is mediated by Rustler's
  `Encoder`/`Decoder` traits; no raw pointers cross the FFI boundary. Binaries
  are borrowed (`&[u8]`) from the BEAM heap and never mutated.
- **Explicit errors** — fallible operations return `Result<T, LuxError>`, which
  Rustler encodes as `{:ok, _} | {:error, %{kind:, message:, detail:}}` so
  Elixir callers can pattern-match on failure.
- **Panic safety** — compute-heavy NIFs are wrapped in `catch_unwind`, turning a
  Rust panic into an `{:error, %{kind: :panic, ...}}` tuple instead of crashing
  the VM.

## Usage

```elixir
Lux.Rust.add(2, 3)              #=> 5
Lux.Rust.factorial(5)           #=> {:ok, 120}
Lux.Rust.factorial(-1)          #=> {:error, %{kind: :invalid_argument, ...}}
Lux.Rust.safe_compute(true)     #=> {:error, %{kind: :panic, ...}}
```

See `guides/rust.md` for the full integration guide.