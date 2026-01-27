//! Lux Rust NIF bindings
//!
//! This module provides Native Implemented Functions (NIFs) for high-performance
//! Rust code execution within the Lux framework.

use rustler::{Error, NifResult};
use std::collections::HashMap;

mod error;
mod types;

pub use error::LuxError;
pub use types::LuxValue;

rustler::init!("Elixir.Lux.Rust.Native");

/// Evaluates a Rust expression with the given variables.
/// This is primarily used for simple computations and type conversions.
///
/// ## Limitations
///
/// Currently supports only single binary operations (e.g., "x + y", "a * b").
/// Complex expressions with multiple operators are not supported and will
/// evaluate incorrectly due to lack of operator precedence handling.
/// For complex expressions, use Elixir's built-in evaluation instead.
#[rustler::nif(schedule = "DirtyCpu")]
fn eval(code: String, variables: HashMap<String, LuxValue>) -> NifResult<LuxValue> {
    // For now, we support basic expression evaluation
    // In the future, this could be extended to support more complex expressions
    match evaluate_expression(&code, &variables) {
        Ok(result) => Ok(result),
        Err(e) => Err(Error::Term(Box::new(e.to_string()))),
    }
}

/// Converts an Elixir term to a JSON string
#[rustler::nif]
fn to_json(value: LuxValue) -> NifResult<String> {
    serde_json::to_string(&value).map_err(|e| Error::Term(Box::new(e.to_string())))
}

/// Parses a JSON string into a Lux value
#[rustler::nif]
fn from_json(json: String) -> NifResult<LuxValue> {
    serde_json::from_str(&json).map_err(|e| Error::Term(Box::new(e.to_string())))
}

/// Returns version information about the Rust integration
#[rustler::nif]
fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Performs a health check to verify the NIF is loaded correctly
#[rustler::nif]
fn health_check() -> NifResult<HashMap<String, LuxValue>> {
    let mut result = HashMap::new();
    result.insert("status".to_string(), LuxValue::String("ok".to_string()));
    result.insert(
        "version".to_string(),
        LuxValue::String(env!("CARGO_PKG_VERSION").to_string()),
    );
    result.insert("language".to_string(), LuxValue::String("rust".to_string()));
    Ok(result)
}

/// Simple expression evaluator for basic operations
fn evaluate_expression(
    code: &str,
    variables: &HashMap<String, LuxValue>,
) -> Result<LuxValue, LuxError> {
    let code = code.trim();

    // Check if it's a simple variable reference
    if let Some(value) = variables.get(code) {
        return Ok(value.clone());
    }

    // Check for simple arithmetic: "x + y", "x - y", "x * y", "x / y"
    for op in [" + ", " - ", " * ", " / "] {
        if let Some(pos) = code.find(op) {
            let left = code[..pos].trim();
            let right = code[pos + op.len()..].trim();

            let left_val = get_number(left, variables)?;
            let right_val = get_number(right, variables)?;

            let result = match op.trim() {
                "+" => left_val + right_val,
                "-" => left_val - right_val,
                "*" => left_val * right_val,
                "/" => {
                    if right_val == 0.0 {
                        return Err(LuxError::DivisionByZero);
                    }
                    left_val / right_val
                }
                _ => return Err(LuxError::UnsupportedOperation(op.to_string())),
            };

            // Return as integer if it's a whole number (use epsilon for float comparison)
            if result.fract().abs() < f64::EPSILON {
                return Ok(LuxValue::Integer(result as i64));
            }
            return Ok(LuxValue::Float(result));
        }
    }

    // Try to parse as a number
    if let Ok(n) = code.parse::<i64>() {
        return Ok(LuxValue::Integer(n));
    }
    if let Ok(n) = code.parse::<f64>() {
        return Ok(LuxValue::Float(n));
    }

    // Try to parse as a string literal
    if code.starts_with('"') && code.ends_with('"') {
        return Ok(LuxValue::String(code[1..code.len() - 1].to_string()));
    }

    // Check if it looks like a variable name
    if code.chars().all(|c| c.is_alphanumeric() || c == '_') && !code.is_empty() {
        return Err(LuxError::VariableNotFound(code.to_string()));
    }

    Err(LuxError::ParseError(format!(
        "Cannot evaluate expression: {}",
        code
    )))
}

fn get_number(s: &str, variables: &HashMap<String, LuxValue>) -> Result<f64, LuxError> {
    // Try variable lookup first
    if let Some(value) = variables.get(s) {
        return match value {
            LuxValue::Integer(n) => Ok(*n as f64),
            LuxValue::Float(n) => Ok(*n),
            _ => Err(LuxError::TypeError(format!(
                "Expected number, got {:?}",
                value
            ))),
        };
    }

    // Try to parse as number
    s.parse::<f64>()
        .map_err(|_| LuxError::ParseError(format!("Cannot parse as number: {}", s)))
}
