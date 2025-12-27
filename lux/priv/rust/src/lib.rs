//! Lux Rust NIF - Native Rust integration for the Lux framework
//!
//! This module provides FFI bindings between Elixir and Rust, enabling
//! high-performance native code execution within Lux components.
//!
//! # Overview
//!
//! The integration provides:
//! - Type-safe conversions between Elixir and Rust types
//! - Error propagation with proper Elixir exception handling
//! - Memory-safe interop via Rustler
//!
//! # Example
//!
//! ```elixir
//! # From Elixir
//! {:ok, result} = Lux.Rust.eval("add", %{a: 1, b: 2})
//! # Returns: {:ok, 3}
//! ```

mod error;
mod types;

use rustler::{Encoder, Env, NifResult, Term};
use std::collections::HashMap;

pub use error::{RustError, RustResult};
pub use types::{ElixirValue, RustValue};

/// Initialize the NIF module
rustler::init!("Elixir.Lux.Rust.Native");

/// Execute a Rust function by name with the given arguments
///
/// This is the main entry point for Elixir code to call into Rust.
/// Functions are dispatched by name and receive a map of arguments.
///
/// # Arguments
///
/// * `func_name` - The name of the function to execute
/// * `args` - A map of arguments to pass to the function
///
/// # Returns
///
/// Returns `{:ok, result}` on success or `{:error, message}` on failure.
#[rustler::nif]
fn execute<'a>(env: Env<'a>, func_name: &str, args: Term<'a>) -> NifResult<Term<'a>> {
    let result = dispatch_function(env, func_name, args);

    match result {
        Ok(value) => Ok((rustler::atoms::ok(), value).encode(env)),
        Err(e) => Ok((rustler::atoms::error(), e.to_string()).encode(env)),
    }
}

/// Evaluate arbitrary Rust code (for dynamic execution)
///
/// This function allows executing predefined Rust operations
/// with runtime-specified parameters.
#[rustler::nif]
fn eval<'a>(env: Env<'a>, code: &str, variables: Term<'a>) -> NifResult<Term<'a>> {
    // Parse variables from Elixir term
    let vars: HashMap<String, RustValue> = match decode_map(env, variables) {
        Ok(v) => v,
        Err(e) => return Ok((rustler::atoms::error(), e.to_string()).encode(env)),
    };

    // Execute the code expression
    let result = execute_expression(code, &vars);

    match result {
        Ok(value) => {
            let encoded = encode_value(env, &value);
            Ok((rustler::atoms::ok(), encoded).encode(env))
        }
        Err(e) => Ok((rustler::atoms::error(), e.to_string()).encode(env)),
    }
}

/// Get version information about the Rust integration
#[rustler::nif]
fn version<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    let version_info: HashMap<&str, &str> = [
        ("version", env!("CARGO_PKG_VERSION")),
        ("rustc", env!("RUSTC_VERSION", "unknown")),
        ("target", env!("TARGET", "unknown")),
    ]
    .into_iter()
    .collect();

    Ok(version_info.encode(env))
}

/// Check if the Rust NIF is properly loaded and functional
#[rustler::nif]
fn health_check<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    Ok((rustler::atoms::ok(), "healthy").encode(env))
}

/// Dispatch a function call to the appropriate handler
fn dispatch_function<'a>(env: Env<'a>, func_name: &str, args: Term<'a>) -> RustResult<Term<'a>> {
    match func_name {
        "add" => builtin_add(env, args),
        "multiply" => builtin_multiply(env, args),
        "concat" => builtin_concat(env, args),
        "hash_sha256" => builtin_hash_sha256(env, args),
        "json_parse" => builtin_json_parse(env, args),
        "json_stringify" => builtin_json_stringify(env, args),
        _ => Err(RustError::UnknownFunction(func_name.to_string())),
    }
}

/// Execute a simple expression with variables
fn execute_expression(code: &str, vars: &HashMap<String, RustValue>) -> RustResult<RustValue> {
    // Parse simple arithmetic expressions
    // Supports: variable references, +, -, *, /
    let code = code.trim();

    // Try to parse as a simple binary operation
    if let Some((op_pos, op)) = find_operator(code) {
        let left = code[..op_pos].trim();
        let right = code[op_pos + 1..].trim();

        let left_val = resolve_value(left, vars)?;
        let right_val = resolve_value(right, vars)?;

        return apply_operator(&left_val, &right_val, op);
    }

    // Try to resolve as a single value
    resolve_value(code, vars)
}

fn find_operator(code: &str) -> Option<(usize, char)> {
    // Find operator, respecting precedence (+ and - last)
    for (i, c) in code.char_indices().rev() {
        if c == '+' || c == '-' {
            return Some((i, c));
        }
    }
    for (i, c) in code.char_indices().rev() {
        if c == '*' || c == '/' {
            return Some((i, c));
        }
    }
    None
}

fn resolve_value(s: &str, vars: &HashMap<String, RustValue>) -> RustResult<RustValue> {
    let s = s.trim();

    // Check if it's a number
    if let Ok(n) = s.parse::<i64>() {
        return Ok(RustValue::Integer(n));
    }
    if let Ok(n) = s.parse::<f64>() {
        return Ok(RustValue::Float(n));
    }

    // Check if it's a string literal
    if (s.starts_with('"') && s.ends_with('"')) || (s.starts_with('\'') && s.ends_with('\'')) {
        return Ok(RustValue::String(s[1..s.len() - 1].to_string()));
    }

    // Check if it's a variable
    if let Some(val) = vars.get(s) {
        return Ok(val.clone());
    }

    Err(RustError::UndefinedVariable(s.to_string()))
}

fn apply_operator(left: &RustValue, right: &RustValue, op: char) -> RustResult<RustValue> {
    match (left, right, op) {
        (RustValue::Integer(a), RustValue::Integer(b), '+') => Ok(RustValue::Integer(a + b)),
        (RustValue::Integer(a), RustValue::Integer(b), '-') => Ok(RustValue::Integer(a - b)),
        (RustValue::Integer(a), RustValue::Integer(b), '*') => Ok(RustValue::Integer(a * b)),
        (RustValue::Integer(a), RustValue::Integer(b), '/') => {
            if *b == 0 {
                Err(RustError::DivisionByZero)
            } else {
                Ok(RustValue::Integer(a / b))
            }
        }
        (RustValue::Float(a), RustValue::Float(b), '+') => Ok(RustValue::Float(a + b)),
        (RustValue::Float(a), RustValue::Float(b), '-') => Ok(RustValue::Float(a - b)),
        (RustValue::Float(a), RustValue::Float(b), '*') => Ok(RustValue::Float(a * b)),
        (RustValue::Float(a), RustValue::Float(b), '/') => {
            if *b == 0.0 {
                Err(RustError::DivisionByZero)
            } else {
                Ok(RustValue::Float(a / b))
            }
        }
        (RustValue::String(a), RustValue::String(b), '+') => {
            Ok(RustValue::String(format!("{}{}", a, b)))
        }
        _ => Err(RustError::TypeMismatch(format!(
            "Cannot apply '{}' to {:?} and {:?}",
            op, left, right
        ))),
    }
}

// Built-in functions

fn builtin_add<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;
    let a = map
        .get("a")
        .ok_or_else(|| RustError::MissingArgument("a".to_string()))?;
    let b = map
        .get("b")
        .ok_or_else(|| RustError::MissingArgument("b".to_string()))?;

    let result = match (a, b) {
        (RustValue::Integer(x), RustValue::Integer(y)) => RustValue::Integer(x + y),
        (RustValue::Float(x), RustValue::Float(y)) => RustValue::Float(x + y),
        (RustValue::Integer(x), RustValue::Float(y)) => RustValue::Float(*x as f64 + y),
        (RustValue::Float(x), RustValue::Integer(y)) => RustValue::Float(x + *y as f64),
        _ => return Err(RustError::TypeMismatch("add requires numeric arguments".into())),
    };

    Ok(encode_value(env, &result))
}

fn builtin_multiply<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;
    let a = map
        .get("a")
        .ok_or_else(|| RustError::MissingArgument("a".to_string()))?;
    let b = map
        .get("b")
        .ok_or_else(|| RustError::MissingArgument("b".to_string()))?;

    let result = match (a, b) {
        (RustValue::Integer(x), RustValue::Integer(y)) => RustValue::Integer(x * y),
        (RustValue::Float(x), RustValue::Float(y)) => RustValue::Float(x * y),
        (RustValue::Integer(x), RustValue::Float(y)) => RustValue::Float(*x as f64 * y),
        (RustValue::Float(x), RustValue::Integer(y)) => RustValue::Float(x * *y as f64),
        _ => {
            return Err(RustError::TypeMismatch(
                "multiply requires numeric arguments".into(),
            ))
        }
    };

    Ok(encode_value(env, &result))
}

fn builtin_concat<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;
    let a = map
        .get("a")
        .ok_or_else(|| RustError::MissingArgument("a".to_string()))?;
    let b = map
        .get("b")
        .ok_or_else(|| RustError::MissingArgument("b".to_string()))?;

    let result = match (a, b) {
        (RustValue::String(x), RustValue::String(y)) => RustValue::String(format!("{}{}", x, y)),
        _ => {
            return Err(RustError::TypeMismatch(
                "concat requires string arguments".into(),
            ))
        }
    };

    Ok(encode_value(env, &result))
}

fn builtin_hash_sha256<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;
    let data = map
        .get("data")
        .ok_or_else(|| RustError::MissingArgument("data".to_string()))?;

    let input = match data {
        RustValue::String(s) => s.as_bytes().to_vec(),
        RustValue::Binary(b) => b.clone(),
        _ => return Err(RustError::TypeMismatch("hash requires string or binary".into())),
    };

    // Simple SHA256 implementation would go here
    // For now, return a placeholder (in production, use ring or sha2 crate)
    let hash = format!("sha256:{:x}", input.iter().fold(0u64, |acc, &x| acc.wrapping_add(x as u64)));

    Ok(encode_value(env, &RustValue::String(hash)))
}

fn builtin_json_parse<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;
    let json_str = map
        .get("json")
        .ok_or_else(|| RustError::MissingArgument("json".to_string()))?;

    let json_str = match json_str {
        RustValue::String(s) => s,
        _ => return Err(RustError::TypeMismatch("json_parse requires string".into())),
    };

    let parsed: serde_json::Value = serde_json::from_str(json_str)
        .map_err(|e| RustError::JsonError(e.to_string()))?;

    let rust_value = json_to_rust_value(&parsed);
    Ok(encode_value(env, &rust_value))
}

fn builtin_json_stringify<'a>(env: Env<'a>, args: Term<'a>) -> RustResult<Term<'a>> {
    let map: HashMap<String, RustValue> = decode_map(env, args)?;
    let value = map
        .get("value")
        .ok_or_else(|| RustError::MissingArgument("value".to_string()))?;

    let json_value = rust_value_to_json(value);
    let json_str = serde_json::to_string(&json_value)
        .map_err(|e| RustError::JsonError(e.to_string()))?;

    Ok(encode_value(env, &RustValue::String(json_str)))
}

// Helper functions for JSON conversion
fn json_to_rust_value(json: &serde_json::Value) -> RustValue {
    match json {
        serde_json::Value::Null => RustValue::Nil,
        serde_json::Value::Bool(b) => RustValue::Boolean(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                RustValue::Integer(i)
            } else if let Some(f) = n.as_f64() {
                RustValue::Float(f)
            } else {
                RustValue::Nil
            }
        }
        serde_json::Value::String(s) => RustValue::String(s.clone()),
        serde_json::Value::Array(arr) => {
            RustValue::List(arr.iter().map(json_to_rust_value).collect())
        }
        serde_json::Value::Object(obj) => RustValue::Map(
            obj.iter()
                .map(|(k, v)| (k.clone(), json_to_rust_value(v)))
                .collect(),
        ),
    }
}

fn rust_value_to_json(value: &RustValue) -> serde_json::Value {
    match value {
        RustValue::Nil => serde_json::Value::Null,
        RustValue::Boolean(b) => serde_json::Value::Bool(*b),
        RustValue::Integer(i) => serde_json::Value::Number((*i).into()),
        RustValue::Float(f) => {
            serde_json::Number::from_f64(*f)
                .map(serde_json::Value::Number)
                .unwrap_or(serde_json::Value::Null)
        }
        RustValue::String(s) => serde_json::Value::String(s.clone()),
        RustValue::Binary(b) => serde_json::Value::String(base64_encode(b)),
        RustValue::Atom(a) => serde_json::Value::String(a.clone()),
        RustValue::List(arr) => {
            serde_json::Value::Array(arr.iter().map(rust_value_to_json).collect())
        }
        RustValue::Map(obj) => serde_json::Value::Object(
            obj.iter()
                .map(|(k, v)| (k.clone(), rust_value_to_json(v)))
                .collect(),
        ),
        RustValue::Tuple(t) => serde_json::Value::Array(t.iter().map(rust_value_to_json).collect()),
    }
}

fn base64_encode(data: &[u8]) -> String {
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut result = String::new();
    for chunk in data.chunks(3) {
        let b = match chunk.len() {
            3 => ((chunk[0] as u32) << 16) | ((chunk[1] as u32) << 8) | (chunk[2] as u32),
            2 => ((chunk[0] as u32) << 16) | ((chunk[1] as u32) << 8),
            1 => (chunk[0] as u32) << 16,
            _ => 0,
        };
        result.push(ALPHABET[((b >> 18) & 0x3F) as usize] as char);
        result.push(ALPHABET[((b >> 12) & 0x3F) as usize] as char);
        result.push(if chunk.len() > 1 { ALPHABET[((b >> 6) & 0x3F) as usize] as char } else { '=' });
        result.push(if chunk.len() > 2 { ALPHABET[(b & 0x3F) as usize] as char } else { '=' });
    }
    result
}

// Type conversion helpers
fn decode_map<'a>(env: Env<'a>, term: Term<'a>) -> RustResult<HashMap<String, RustValue>> {
    use rustler::types::map::MapIterator;

    let mut result = HashMap::new();

    if term.is_map() {
        if let Ok(iter) = MapIterator::new(term) {
            for (key, value) in iter {
                let key_str: String = key
                    .decode()
                    .or_else(|_| {
                        // Try to decode as atom
                        key.atom_to_string().map_err(|_| rustler::Error::BadArg)
                    })
                    .map_err(|_| RustError::DecodingError("Invalid map key".to_string()))?;

                let rust_value = decode_term(env, value)?;
                result.insert(key_str, rust_value);
            }
        }
    }

    Ok(result)
}

fn decode_term<'a>(_env: Env<'a>, term: Term<'a>) -> RustResult<RustValue> {
    // Try integer
    if let Ok(i) = term.decode::<i64>() {
        return Ok(RustValue::Integer(i));
    }

    // Try float
    if let Ok(f) = term.decode::<f64>() {
        return Ok(RustValue::Float(f));
    }

    // Try string/binary
    if let Ok(s) = term.decode::<String>() {
        return Ok(RustValue::String(s));
    }

    // Try boolean
    if let Ok(b) = term.decode::<bool>() {
        return Ok(RustValue::Boolean(b));
    }

    // Try atom
    if let Ok(s) = term.atom_to_string() {
        if s == "nil" {
            return Ok(RustValue::Nil);
        }
        return Ok(RustValue::Atom(s));
    }

    // Default to nil for unsupported types
    Ok(RustValue::Nil)
}

fn encode_value<'a>(env: Env<'a>, value: &RustValue) -> Term<'a> {
    match value {
        RustValue::Nil => rustler::types::atom::nil().encode(env),
        RustValue::Boolean(b) => b.encode(env),
        RustValue::Integer(i) => i.encode(env),
        RustValue::Float(f) => f.encode(env),
        RustValue::String(s) => s.encode(env),
        RustValue::Binary(b) => b.as_slice().encode(env),
        RustValue::Atom(a) => {
            // Create atom from string
            rustler::types::atom::Atom::from_str(env, a)
                .map(|atom| atom.encode(env))
                .unwrap_or_else(|_| a.encode(env))
        }
        RustValue::List(items) => {
            let encoded: Vec<Term<'a>> = items.iter().map(|v| encode_value(env, v)).collect();
            encoded.encode(env)
        }
        RustValue::Map(map) => {
            let pairs: Vec<(Term<'a>, Term<'a>)> = map
                .iter()
                .map(|(k, v)| (k.encode(env), encode_value(env, v)))
                .collect();
            Term::map_from_pairs(env, &pairs).unwrap_or_else(|_| rustler::types::atom::nil().encode(env))
        }
        RustValue::Tuple(items) => {
            let encoded: Vec<Term<'a>> = items.iter().map(|v| encode_value(env, v)).collect();
            rustler::types::tuple::make_tuple(env, &encoded)
        }
    }
}
