//! # Lux Rust Core
//!
//! Native (Rust) core for the [Lux](https://github.com/Spectral-Finance/lux)
//! framework. This crate is compiled as a `cdylib` and loaded into the BEAM as a
//! [Rustler](https://github.com/rusterlium/rustler) NIF, giving Lux agents access
//! to memory-safe, high-performance native code with idiomatic Elixir-style
//! `{:ok, _} | {:error, _}` return contracts.
//!
//! ## Layout
//!
//! * [`convert`]  – type conversion layer between Elixir terms and Rust primitives.
//! * [`error`]    – error handling framework with structured, propagatable errors.
//! * [`nifs`]     – the NIF functions exported to Elixir (`Lux.Rust`).
//!
//! ## Design goals
//!
//! * **Memory safety** – every boundary crossing is mediated by Rustler's
//!   `Encoder`/`Decoder` traits; no raw pointers cross the FFI boundary.
//! * **Explicit errors** – fallible operations return `{:error, reason}` tuples
//!   instead of raising, so Elixir callers can pattern-match on failure.
//! * **Zero-copy where possible** – binaries are borrowed from the BEAM heap
//!   rather than copied unless ownership is required.

pub mod convert;
pub mod error;
pub mod nifs;

/// Crate version, surfaced to Elixir via `Lux.Rust.core_version/0`.
pub const CORE_VERSION: &str = env!("CARGO_PKG_VERSION");

rustler::init!("Elixir.Lux.Rust", load = load_nif);

fn load_nif(env: rustler::Env, _info: rustler::Term) -> bool {
    // Register the module's NIFs. Returning `true` tells the BEAM the load
    // succeeded. `nif` functions are declared with `#[rustler::nif]` below.
    let _ = env;
    nifs::on_load()
}