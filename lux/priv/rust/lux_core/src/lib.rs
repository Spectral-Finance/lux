use rustler::{Encoder, Env, NifResult, Term, Error};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        division_by_zero,
        allocation_failed,
    }
}

/// Basic type conversion examples
#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn concat_strings(a: String, b: String) -> String {
    format!("{}{}", a, b)
}

/// Error handling framework propagation
#[rustler::nif]
fn safe_divide<'a>(env: Env<'a>, a: f64, b: f64) -> (rustler::Atom, Term<'a>) {
    if b == 0.0 {
        (atoms::error(), atoms::division_by_zero().encode(env))
    } else {
        (atoms::ok(), (a / b).encode(env))
    }
}

/// Memory safe buffer processing (Binary FFI)
#[rustler::nif]
fn reverse_bytes<'a>(env: Env<'a>, binary: rustler::Binary<'a>) -> (rustler::Atom, Term<'a>) {
    let mut reversed: Vec<u8> = binary.as_slice().to_vec();
    reversed.reverse();
    
    match rustler::OwnedBinary::new(reversed.len()) {
        Some(mut erl_bin) => {
            erl_bin.as_mut_slice().copy_from_slice(&reversed);
            (atoms::ok(), erl_bin.release(env).encode(env))
        }
        None => (atoms::error(), atoms::allocation_failed().encode(env)),
    }
}

rustler::init!("Elixir.Lux.Rust.Core");
