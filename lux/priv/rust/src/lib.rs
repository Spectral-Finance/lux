//! Lux Rust NIF bindings
//!
//! This module provides Native Implemented Functions (NIFs) for high-performance
//! Rust code execution within the Lux framework.

use rustler::{Error, NifResult};
use std::collections::HashMap;

const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Maximum allowed code length (64KB)
const MAX_CODE_LENGTH: usize = 64 * 1024;

/// Maximum allowed variables count
const MAX_VARIABLES: usize = 1000;

mod error;
mod types;

pub use error::LuxError;
pub use types::LuxValue;

rustler::init!("Elixir.Lux.Rust.Native");

/// Evaluates a Rust expression with the given variables.
///
/// Supports only **single** binary operations (e.g., "x + y", "a * b").
/// Expressions with multiple operators will return an error.
#[rustler::nif(schedule = "DirtyCpu")]
fn eval(code: String, variables: HashMap<String, LuxValue>) -> NifResult<LuxValue> {
    // Input validation
    if code.len() > MAX_CODE_LENGTH {
        return Err(Error::Term(Box::new("Code exceeds maximum length".to_string())));
    }
    if variables.len() > MAX_VARIABLES {
        return Err(Error::Term(Box::new("Too many variables".to_string())));
    }

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
fn version() -> &'static str {
    VERSION
}

/// Performs a health check to verify the NIF is loaded correctly
#[rustler::nif]
fn health_check() -> NifResult<HashMap<String, LuxValue>> {
    let mut result = HashMap::new();
    result.insert("status".to_string(), LuxValue::String("ok".to_string()));
    result.insert("version".to_string(), LuxValue::String(VERSION.to_string()));
    result.insert("language".to_string(), LuxValue::String("rust".to_string()));
    Ok(result)
}

const OPERATORS: [&str; 4] = [" + ", " - ", " * ", " / "];

/// Counts how many operators are present in the expression
fn count_operators(code: &str) -> usize {
    OPERATORS.iter().filter(|op| code.contains(*op)).count()
}

/// Simple expression evaluator for basic operations
fn evaluate_expression(
    code: &str,
    variables: &HashMap<String, LuxValue>,
) -> Result<LuxValue, LuxError> {
    let code = code.trim();

    // Reject expressions with multiple different operators
    let op_count = count_operators(code);
    if op_count > 1 {
        return Err(LuxError::ParseError(
            "Multiple operators not supported. Use single operations only.".to_string(),
        ));
    }

    // Check if it's a simple variable reference
    if let Some(value) = variables.get(code) {
        return Ok(value.clone());
    }

    // Check for simple arithmetic: "x + y", "x - y", "x * y", "x / y"
    for op in OPERATORS {
        if let Some(pos) = code.find(op) {
            // Check for multiple occurrences of the same operator
            let remainder = &code[pos + op.len()..];
            if remainder.contains(op) {
                return Err(LuxError::ParseError(
                    "Multiple operators not supported. Use single operations only.".to_string(),
                ));
            }

            let left = code[..pos].trim();
            let right = remainder.trim();

            let left_val = get_value(left, variables)?;
            let right_val = get_value(right, variables)?;

            return compute_result(op.trim(), left_val, right_val);
        }
    }

    // Try to parse as a number
    if let Ok(n) = code.parse::<i64>() {
        return Ok(LuxValue::Integer(n));
    }
    if let Ok(n) = code.parse::<f64>() {
        return Ok(LuxValue::Float(n));
    }

    // Check if it looks like a variable name
    if is_valid_identifier(code) {
        return Err(LuxError::VariableNotFound(code.to_string()));
    }

    Err(LuxError::ParseError(format!(
        "Cannot evaluate expression: {}",
        code
    )))
}

/// Checks if the string is a valid identifier (variable name)
fn is_valid_identifier(s: &str) -> bool {
    if s.is_empty() {
        return false;
    }
    let mut chars = s.chars();
    // First character must be alphabetic or underscore
    match chars.next() {
        Some(c) if c.is_alphabetic() || c == '_' => {}
        _ => return false,
    }
    // Rest can be alphanumeric or underscore
    chars.all(|c| c.is_alphanumeric() || c == '_')
}

/// Represents a numeric value for arithmetic operations
enum NumericValue {
    Int(i64),
    Float(f64),
}

/// Computes the arithmetic result with overflow checking
fn compute_result(op: &str, left: NumericValue, right: NumericValue) -> Result<LuxValue, LuxError> {
    use NumericValue::*;

    // If both are integers, try integer arithmetic first
    if let (Int(l), Int(r)) = (&left, &right) {
        if let Some(result) = compute_integer_result(op, *l, *r)? {
            return Ok(LuxValue::Integer(result));
        }
        // Overflow: fall through to float arithmetic
    }

    // Float arithmetic
    let l = match left {
        Int(n) => n as f64,
        Float(n) => n,
    };
    let r = match right {
        Int(n) => n as f64,
        Float(n) => n,
    };

    let result = match op {
        "+" => l + r,
        "-" => l - r,
        "*" => l * r,
        "/" => {
            if r == 0.0 {
                return Err(LuxError::DivisionByZero);
            }
            l / r
        }
        _ => return Err(LuxError::UnsupportedOperation(op.to_string())),
    };

    // Check for overflow/infinity
    if result.is_infinite() || result.is_nan() {
        return Err(LuxError::TypeError("Arithmetic overflow or invalid result".to_string()));
    }

    Ok(LuxValue::Float(result))
}

/// Tries to compute integer result, returns None on overflow or non-integer result
fn compute_integer_result(op: &str, left: i64, right: i64) -> Result<Option<i64>, LuxError> {
    let result = match op {
        "+" => left.checked_add(right),
        "-" => left.checked_sub(right),
        "*" => left.checked_mul(right),
        "/" => {
            if right == 0 {
                return Err(LuxError::DivisionByZero);
            }
            // Only return integer if division is exact
            // Use checked_rem to avoid panic on i64::MIN % -1
            match left.checked_rem(right) {
                Some(0) => left.checked_div(right),
                Some(_) => return Ok(None), // Fall through to float division
                None => return Ok(None),    // Overflow (e.g., i64::MIN / -1)
            }
        }
        _ => return Err(LuxError::UnsupportedOperation(op.to_string())),
    };
    Ok(result)
}

/// Gets a numeric value from a string or variable
fn get_value(s: &str, variables: &HashMap<String, LuxValue>) -> Result<NumericValue, LuxError> {
    // Try variable lookup first
    if let Some(value) = variables.get(s) {
        return match value {
            LuxValue::Integer(n) => Ok(NumericValue::Int(*n)),
            LuxValue::Float(n) => Ok(NumericValue::Float(*n)),
            _ => Err(LuxError::TypeError(format!(
                "Expected number, got {:?}",
                value
            ))),
        };
    }

    // Try to parse as integer first (preserves precision)
    if let Ok(n) = s.parse::<i64>() {
        return Ok(NumericValue::Int(n));
    }

    // Try to parse as float
    s.parse::<f64>()
        .map(NumericValue::Float)
        .map_err(|_| LuxError::ParseError(format!("Cannot parse as number: {}", s)))
}
