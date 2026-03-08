use thiserror::Error;

#[derive(Error, Debug)]
pub enum LuxError {
    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("Type mismatch: expected {expected}, got {got}")]
    TypeError { expected: String, got: String },

    #[error("Unknown type: {0}")]
    UnknownType(String),

    #[error("Conversion error: {0}")]
    ConversionError(String),
}

/// Helper to create a Rustler :error atom
pub fn error_atom() -> rustler::Atom {
    rustler::types::atom::error()
}
