use rustler::{Env, Term, Atom, Encoder};
pub mod errors;
pub mod types;

use types::{ExamplePayload, ComplexData};

/// Demonstrates basic type conversion (primitives)
#[rustler::nif(schedule = "DirtyCpu")]
fn reverse_string(input: String) -> String {
    input.chars().rev().collect()
}

/// Demonstrates robust error handling. Returns `{:ok, result}` or `{:error, reason}`
#[rustler::nif]
fn parse_number(env: Env, input: String) -> rustler::NifResult<Term> {
    match input.parse::<f64>() {
        Ok(num) => crate::ok_tuple!(env, num),
        Err(_) => crate::error_tuple!(env, errors::invalid_type()),
    }
}

/// Demonstrates dealing with maps/structs and vectors
#[rustler::nif(schedule = "DirtyCpu")]
fn process_payload(env: Env, payload: ExamplePayload) -> rustler::NifResult<Term> {
    if payload.is_active {
        let new_data = format!("{}_processed", payload.data);
        crate::ok_tuple!(env, new_data)
    } else {
        crate::error_tuple!(env, "payload_inactive")
    }
}

/// Demonstrates complex nested structs with Ex/Rust conversions
#[rustler::nif(schedule = "DirtyCpu")]
fn transform_complex(env: Env, data: ComplexData) -> rustler::NifResult<Term> {
    // Modify the data natively
    let mut modified = data;
    modified.name = modified.name.to_uppercase();
    modified.items.push("Native Item".to_string());
    
    crate::ok_tuple!(env, modified)
}

rustler::init!("Elixir.Lux.Native", [
    reverse_string,
    parse_number,
    process_payload,
    transform_complex
]);
