//! Error types for Lux Rust integration
//!
//! This module defines the error types used throughout the Rust NIF bindings,
//! providing proper error propagation between Rust and Elixir.

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
}
