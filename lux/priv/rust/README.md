# Lux Rust Components

This directory contains the Rust components of the Lux framework. It is
structured as a [Cargo workspace](https://doc.rust-lang.org/cargo/reference/workspaces.html)
and ships the **Lux Rust Testing Framework** that lets contributors
develop and verify Rust-side primitives with the same red-green-refactor
discipline used on the Elixir and Python sides.

## Layout

```
priv/rust/
├── Cargo.toml           # Workspace manifest
└── lux_core/            # Core crate (signals, testing helpers, …)
    ├── Cargo.toml
    ├── src/
    │   ├── lib.rs       # Public API + crate-level docs
    │   ├── signal.rs    # Signal type — counterpart to Lux.Signal
    │   └── testing.rs   # Testing framework (Recorder, fixtures, asserts)
    └── tests/
        └── smoke_test.rs  # Black-box integration tests
```

## Running Tests

### From the Elixir project root

```bash
# All Rust tests, with Cargo installed via rustup or asdf
mix rust.test

# Forward arbitrary arguments to `cargo test`
mix rust.test -- --nocapture
mix rust.test signal::tests::new_signal_has_no_metadata
mix rust.test --release
```

### Directly with Cargo

```bash
cd priv/rust

# Whole workspace
cargo test --workspace

# A single crate
cargo test -p lux_core

# A single integration suite
cargo test --test smoke_test

# A single test by path
cargo test signal::tests::new_signal_has_no_metadata
```

## The Testing Framework

`lux_core::testing` exposes a tiny, dependency-free API:

| Helper | Purpose |
| --- | --- |
| `assert_eq_with_context` | `assert_eq!` with a labelled failure message |
| `assert_runs_within`     | Latency guardrail for fast paths |
| `Recorder<T>`            | Captures every value passed to it for later inspection |
| `sample_signal`          | Canonical [`Signal`](lux_core/src/signal.rs) fixture |

The framework uses only the standard `cargo test` harness so contributors
don't need to install any extra tooling. Optional crates such as
`proptest` or `criterion` can be added under `[dev-dependencies]` in
`lux_core/Cargo.toml` when the need arises.

## Requirements

- Rust toolchain (recommended: `rustup` or `asdf rust 1.74` or newer)
- `cargo` on `PATH`

The `mix rust.test` task validates these prerequisites and prints an
actionable error message if `cargo` is missing.

## Adding a New Crate

1. Create the crate directory under `priv/rust/`.
2. Add it to the `members` list of `priv/rust/Cargo.toml`.
3. Inherit the workspace settings via `edition.workspace = true` etc.
4. Write unit tests inline (`#[cfg(test)] mod tests`) and integration
   tests under `tests/`.
5. Run `mix rust.test` to make sure everything still passes.

## Integration with Elixir

A future PR will wire `lux_core` to the Elixir runtime via
[`rustler`](https://github.com/rusterlium/rustler) so that Prisms, Beams
and Signals can be implemented natively in Rust. The testing framework
introduced here is the substrate that work will build on.
