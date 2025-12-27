//! Error types for Lux Rust integration
//!
//! This module defines the error types used throughout the Rust NIF,
//! providing proper error propagation back to Elixir.

use thiserror::Error;

/// Result type alias for Rust NIF operations
pub type RustResult<T> = Result<T, RustError>;

/// Error types that can occur during Rust NIF execution
#[derive(Error, Debug)]
pub enum RustError {
    /// Function not found in the dispatch table
    #[error("Unknown function: {0}")]
    UnknownFunction(String),

    /// Required argument was not provided
    #[error("Missing required argument: {0}")]
    MissingArgument(String),

    /// Type mismatch between expected and actual types
    #[error("Type mismatch: {0}")]
    TypeMismatch(String),

    /// Division by zero attempted
    #[error("Division by zero")]
    DivisionByZero,

    /// Variable not found in the current scope
    #[error("Undefined variable: {0}")]
    UndefinedVariable(String),

    /// Error during term decoding from Elixir
    #[error("Decoding error: {0}")]
    DecodingError(String),

    /// Error during term encoding to Elixir
    #[error("Encoding error: {0}")]
    EncodingError(String),

    /// JSON parsing or serialization error
    #[error("JSON error: {0}")]
    JsonError(String),

    /// Generic execution error
    #[error("Execution error: {0}")]
    ExecutionError(String),

    /// Memory allocation error
    #[error("Memory error: {0}")]
    MemoryError(String),

    /// Timeout during execution
    #[error("Execution timed out")]
    Timeout,
}

impl RustError {
    /// Create a new execution error with a custom message
    pub fn execution<S: Into<String>>(msg: S) -> Self {
        RustError::ExecutionError(msg.into())
    }

    /// Create a new type mismatch error
    pub fn type_mismatch<S: Into<String>>(expected: S, got: S) -> Self {
        RustError::TypeMismatch(format!("expected {}, got {}", expected.into(), got.into()))
    }
}

/// Convert RustError to a format suitable for Elixir error tuples
impl From<RustError> for String {
    fn from(error: RustError) -> Self {
        error.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_messages() {
        let err = RustError::UnknownFunction("foo".to_string());
        assert_eq!(err.to_string(), "Unknown function: foo");

        let err = RustError::MissingArgument("bar".to_string());
        assert_eq!(err.to_string(), "Missing required argument: bar");

        let err = RustError::DivisionByZero;
        assert_eq!(err.to_string(), "Division by zero");
    }

    #[test]
    fn test_type_mismatch_helper() {
        let err = RustError::type_mismatch("integer", "string");
        assert!(err.to_string().contains("expected integer, got string"));
    }
}
