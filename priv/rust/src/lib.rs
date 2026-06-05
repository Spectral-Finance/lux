
use rustler::{Encoder, Env, Term, NifResult, Error};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn version() -> String {
    "lux-rust-0.1.0".to_string()
}

#[rustler::nif]
fn ping() -> String {
    "pong".to_string()
}

rustler::init!("Elixir.Lux.Rust.Native", [add, version, ping]);
