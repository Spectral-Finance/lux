//! Lux core NIFs.
//!
//! All exported functions are registered on `Elixir.Lux.Rust.Native`.
//! Failures are returned as `{:error, reason}` terms; they do not panic
//! across the FFI boundary or take down the BEAM.

mod error;
mod types;

use error::{atoms, LuxError};
use rustler::{Encoder, Env, Term};
use types::Converted;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

fn load(_env: Env, _info: Term) -> bool {
    true
}

fn ok<'a>(env: Env<'a>, value: impl Encoder) -> Term<'a> {
    (atoms::ok(), value).encode(env)
}

fn err<'a>(env: Env<'a>, error: LuxError) -> Term<'a> {
    (atoms::error(), error.reason_tuple(env)).encode(env)
}

#[rustler::nif]
fn version(env: Env) -> Term {
    VERSION.encode(env)
}

/// Integer addition used as a smoke-test for primitive integer conversion.
#[rustler::nif]
fn add(env: Env, a: i64, b: i64) -> Term {
    match a.checked_add(b) {
        Some(sum) => sum.encode(env),
        None => err(env, LuxError::runtime("integer overflow")),
    }
}

/// Checked division so error propagation can be tested without panics.
#[rustler::nif]
fn divide(env: Env, a: i64, b: i64) -> Term {
    if b == 0 {
        return err(env, LuxError::runtime("division by zero"));
    }
    match a.checked_div(b) {
        Some(q) => q.encode(env),
        None => err(env, LuxError::runtime("integer overflow")),
    }
}

/// Decode a term into an owned Rust value and encode it back.
/// Demonstrates the conversion layer and that no BEAM pointers are retained.
#[rustler::nif]
fn echo<'a>(env: Env<'a>, term: Term<'a>) -> Term<'a> {
    match Converted::from_term(term) {
        Ok(converted) => match converted.to_term(env) {
            Ok(encoded) => encoded,
            Err(rustler::Error::Term(reason)) => (atoms::error(), reason.encode(env)).encode(env),
            Err(_) => err(env, LuxError::conversion("failed to re-encode term")),
        },
        Err(rustler::Error::Term(reason)) => (atoms::error(), reason.encode(env)).encode(env),
        Err(_) => err(env, LuxError::conversion("failed to decode term")),
    }
}

/// Return `%{"type" => ..., "value" => ...}` for a term.
#[rustler::nif]
fn describe<'a>(env: Env<'a>, term: Term<'a>) -> Term<'a> {
    match Converted::from_term(term).and_then(|c| c.describe(env)) {
        Ok(desc) => desc,
        Err(rustler::Error::Term(reason)) => (atoms::error(), reason.encode(env)).encode(env),
        Err(_) => err(env, LuxError::conversion("failed to describe term")),
    }
}

/// Force a typed conversion error (used by tests).
#[rustler::nif]
fn type_error(env: Env) -> Term {
    err(env, LuxError::type_error("integer", "atom"))
}

/// Iterative Fibonacci on a dirty CPU scheduler so long work does not
/// block the normal BEAM scheduler.
#[rustler::nif(schedule = "DirtyCpu")]
fn fib(env: Env, n: u64) -> Term {
    if n > 92 {
        return err(env, LuxError::runtime("fib overflow: n must be <= 92 for u64"));
    }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    for _ in 0..n {
        match a.checked_add(b) {
            Some(next) => {
                a = b;
                b = next;
            }
            None => return err(env, LuxError::runtime("fib overflow")),
        }
    }
    a.encode(env)
}

/// Explicit ok-tuple helper so Elixir can match `{:ok, term}` from Rust.
#[rustler::nif]
fn wrap_ok<'a>(env: Env<'a>, term: Term<'a>) -> Term<'a> {
    ok(env, term)
}

rustler::init!("Elixir.Lux.Rust.Native", load = load);
