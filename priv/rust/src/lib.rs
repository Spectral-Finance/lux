//! Lux Rust Integration
//!
//! This module provides the Rust backend for Lux, enabling high-performance
//! native code execution and FFI bindings with Elixir.

#[macro_use]
extern crate rustler;

use rustler::{NifResult, Encoder, Env, Error, Term};
use serde::{Deserialize, Serialize};
use std::convert::TryFrom;

mod types;
mod error;
mod nif_bindings;

pub use error::LuxError;
pub use types::{LuxString, LuxInteger, LuxFloat, LuxBoolean};

/// Initialize the Rust NIFs for Lux
fn load(_env: Env, _info: Term) -> bool {
    true
}

/// Example function that adds two integers
fn add(env: Env, args: &[Term]) -> NifResult<Term> {
    let a: i64 = args[0].decode()?;
    let b: i64 = args[1].decode()?;
    Ok((a + b).encode(env))
}

/// Convert Elixir string to Rust string
fn echo_string(env: Env, args: &[Term]) -> NifResult<Term> {
    let input: String = args[0].decode()?;
    Ok(input.encode(env))
}

/// Process a LuxString type
fn process_lux_string(env: Env, args: &[Term]) -> NifResult<Term> {
    let lux_str: types::LuxString = args[0].decode()?;
    Ok(lux_str.encode(env))
}

/// Process a LuxInteger type
fn process_lux_integer(env: Env, args: &[Term]) -> NifResult<Term> {
    let lux_int: types::LuxInteger = args[0].decode()?;
    Ok(lux_int.encode(env))
}

/// Process a LuxFloat type
fn process_lux_float(env: Env, args: &[Term]) -> NifResult<Term> {
    let lux_float: types::LuxFloat = args[0].decode()?;
    Ok(lux_float.encode(env))
}

/// Process a LuxBoolean type
fn process_lux_boolean(env: Env, args: &[Term]) -> NifResult<Term> {
    let lux_bool: types::LuxBoolean = args[0].decode()?;
    Ok(lux_bool.encode(env))
}

/// Example function that demonstrates error handling
fn divide(env: Env, args: &[Term]) -> NifResult<Term> {
    let a: f64 = args[0].decode()?;
    let b: f64 = args[1].decode()?;
    
    if b == 0.0 {
        return Err(error::LuxError::DivisionByZero.into());
    }
    
    Ok((a / b).encode(env))
}

/// Create a LuxError from a string message
fn create_error(_env: Env, args: &[Term]) -> NifResult<Term> {
    let error_msg: String = args[0].decode()?;
    Err(Error::RaiseTerm(Box::new(error_msg)))
}

/// NIF function definitions
rustler::init!(
    "Elixir.Lux.Rust",
    [
        add,
        echo_string,
        process_lux_string,
        process_lux_integer,
        process_lux_float,
        process_lux_boolean,
        divide,
        create_error,
    ],
    load = load
);

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_addition() {
        assert_eq!(2 + 2, 4);
    }
    
    #[test]
    fn test_lux_string_creation() {
        let lux_str = types::LuxString::new("test".to_string());
        assert_eq!(lux_str.value, "test");
    }
    
    #[test]
    fn test_lux_integer_creation() {
        let lux_int = types::LuxInteger::new(42);
        assert_eq!(lux_int.value, 42);
    }
    
    #[test]
    fn test_lux_float_creation() {
        let lux_float = types::LuxFloat::new(3.14);
        assert_eq!(lux_float.value, 3.14);
    }
    
    #[test]
    fn test_lux_boolean_creation() {
        let lux_bool = types::LuxBoolean::new(true);
        assert_eq!(lux_bool.value, true);
    }
}