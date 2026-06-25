use rustler::{Atom, Encoder, Env, Error as RustlerError, NifResult, Term};
use std::sync::Arc;

mod atoms;
mod conversion;
mod error;

use conversion::{from_elixir, to_elixir, ElixirTerm, RustValue};
use error::LuxError;

rustler::init!("Elixir.Lux.RustCore", [add, echo, convert, safe_divide]);

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn echo(term: Term) -> NifResult<Term> {
    Ok(term)
}

#[rustler::nif]
fn convert(env: Env, term: Term) -> NifResult<Term> {
    let elixir_term = from_elixir(term)?;
    let rust_value = elixir_term.to_rust();
    to_elixir(env, &rust_value)
}

#[rustler::nif]
fn safe_divide(a: f64, b: f64) -> NifResult<f64> {
    if b == 0.0 {
        return Err(RustlerError::Term(Box::new(LuxError::DivisionByZero)));
    }
    Ok(a / b)
}