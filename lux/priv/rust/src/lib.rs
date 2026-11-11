//! Core Rust runtime integration and NIF bindings for Lux (`priv/rust`).
//! Provides primitive type conversions, structured error propagation, and memory-safe FFI execution.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum LuxPrimitive {
    Integer(i64),
    Float(f64),
    Boolean(bool),
    Text(String),
    Bytes(Vec<u8>),
    List(Vec<LuxPrimitive>),
    Map(HashMap<String, LuxPrimitive>),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LuxFfiError {
    pub code: String,
    pub message: String,
    pub recoverable: bool,
}

impl LuxFfiError {
    pub fn new(code: &str, message: &str, recoverable: bool) -> Self {
        Self {
            code: code.to_string(),
            message: message.to_string(),
            recoverable,
        }
    }
}

/// Memory-safe execution guard ensuring bounded input byte size and finite floats.
pub fn validate_primitive(value: &LuxPrimitive, max_bytes: usize) -> Result<(), LuxFfiError> {
    match value {
        LuxPrimitive::Float(v) if !v.is_finite() => Err(LuxFfiError::new(
            "non_finite_float",
            "Floating-point value must be finite across FFI boundary",
            false,
        )),
        LuxPrimitive::Text(s) if s.len() > max_bytes => Err(LuxFfiError::new(
            "payload_too_large",
            "String exceeds maximum FFI buffer size",
            false,
        )),
        LuxPrimitive::Bytes(b) if b.len() > max_bytes => Err(LuxFfiError::new(
            "payload_too_large",
            "Byte buffer exceeds maximum FFI buffer size",
            false,
        )),
        LuxPrimitive::List(items) => {
            for item in items {
                validate_primitive(item, max_bytes)?;
            }
            Ok(())
        }
        LuxPrimitive::Map(entries) => {
            for v in entries.values() {
                validate_primitive(v, max_bytes)?;
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

/// Deterministic vector dot product over validated FFI slices.
pub fn dot_product_f64(a: &[f64], b: &[f64]) -> Result<f64, LuxFfiError> {
    if a.len() != b.len() {
        return Err(LuxFfiError::new(
            "dimension_mismatch",
            "Input slices must have equal length",
            false,
        ));
    }
    let mut sum = 0.0_f64;
    for (x, y) in a.iter().zip(b.iter()) {
        if !x.is_finite() || !y.is_finite() {
            return Err(LuxFfiError::new(
                "non_finite_float",
                "Slice contains NaN or Infinity",
                false,
            ));
        }
        sum += x * y;
    }
    Ok(sum)
}
