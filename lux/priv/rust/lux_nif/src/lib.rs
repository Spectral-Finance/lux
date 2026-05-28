mod types;

use rustler::{Encoder, Env, NifResult, Term};

rustler::atoms! {
    ok,
    error,
    nil,
    lux_nif_loaded,
}

/// Returns a confirmation atom that the NIF library was loaded successfully.
///
/// Called from `Lux.Rust.NIF.load/2` as a smoke-test after `:erlang.load_nif/2`
/// succeeds.
#[rustler::nif]
fn ping(env: Env) -> Term {
    lux_nif_loaded().encode(env)
}

/// Adds two 64-bit integers and returns the result.
///
/// Used as a baseline integration test to confirm that argument passing and
/// return-value encoding work correctly end-to-end.
#[rustler::nif]
fn add_integers(a: i64, b: i64) -> NifResult<i64> {
    Ok(a + b)
}

/// Reverses a UTF-8 string and returns it.
#[rustler::nif]
fn reverse_string(s: String) -> NifResult<String> {
    Ok(s.chars().rev().collect())
}

/// Converts a list of integers to their absolute values.
#[rustler::nif]
fn abs_list(items: Vec<i64>) -> NifResult<Vec<i64>> {
    Ok(items.into_iter().map(|x| x.abs()).collect())
}

rustler::init!("Elixir.Lux.Rust.NIF.Native");
