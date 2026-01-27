//! Error types for Lux Rust integration
//!
//! This module defines the error types used throughout the Rust NIF bindings,
//! providing proper error propagation between Rust and Elixir.

use rustler::{Encoder, Env, Term};
use thiserror::Error;

/// Errors that can occur during Lux Rust operations
#[derive(Error, Debug)]
pub enum LuxError {
    /// Error during expression parsing
    #[error("Parse error: {0}")]
    ParseError(String),

    /// Type mismatch error
    #[error("Type error: {0}")]
    TypeError(String),

    /// Division by zero
    #[error("Division by zero")]
    DivisionByZero,

    /// Unsupported operation
    #[error("Unsupported operation: {0}")]
    UnsupportedOperation(String),

    /// Variable not found
    #[error("Variable not found: {0}")]
    VariableNotFound(String),

    /// JSON serialization/deserialization error
    #[error("JSON error: {0}")]
    JsonError(String),

    /// Generic runtime error
    #[error("Runtime error: {0}")]
    RuntimeError(String),
}

impl Encoder for LuxError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let error_type = match self {
            LuxError::ParseError(_) => "parse_error",
            LuxError::TypeError(_) => "type_error",
            LuxError::DivisionByZero => "division_by_zero",
            LuxError::UnsupportedOperation(_) => "unsupported_operation",
            LuxError::VariableNotFound(_) => "variable_not_found",
            LuxError::JsonError(_) => "json_error",
            LuxError::RuntimeError(_) => "runtime_error",
        };

        let message = self.to_string();

        // Return as {:error, {error_type, message}}
        (
            rustler::types::atom::error(),
            (error_type.encode(env), message.encode(env)),
        )
            .encode(env)
    }
}

impl From<serde_json::Error> for LuxError {
    fn from(err: serde_json::Error) -> Self {
        LuxError::JsonError(err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = LuxError::ParseError("invalid syntax".to_string());
        assert_eq!(err.to_string(), "Parse error: invalid syntax");

        let err = LuxError::DivisionByZero;
        assert_eq!(err.to_string(), "Division by zero");
    }
}
