# lux_core

Rustler NIF crate for [Lux](https://github.com/Spectral-Finance/lux).

Elixir talks to this crate through `Lux.Rust` / `Lux.Rust.Native`. Terms are
decoded into owned `Converted` values, so handlers never keep BEAM pointers.
Errors are `{error, reason}` tuples; the NIF must not panic.

## Layout

- `src/lib.rs` — NIF exports (`version`, `add`, `echo`, component lifecycle)
- `src/types.rs` — Elixir term <-> owned Rust conversion
- `src/error.rs` — typed `{error, {type|conversion|runtime, ...}}` reasons
- `src/component.rs` — Prism/Beam registry and lifecycle
- `src/builtins.rs` — echo, hash, fib, map_get, sleep, sequence
- `src/async_rt.rs` — shared Tokio runtime for async handlers

## Build

From the `lux/` Mix project:

```
mix deps.get
mix compile
```

Rustler builds `lux_core` automatically. Requires a stable Rust toolchain.

## Safety

- Dirty CPU scheduler for `fib`, `component_run`, and `component_run_async`
- Checked integer arithmetic
- `OnceLock` Tokio runtime, created on first use
- No retained `Term` / env pointers after a NIF returns
