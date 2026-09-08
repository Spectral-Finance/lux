//! Error type for the Lux Rust NIF.
//!
//! All recoverable failures are converted into Elixir `{:error, reason}` tuples
//! by Rustler (`NifResult`). Nothing in this module panics across the FFI
//! boundary.

use rustler::{Encoder, Env, Term};
use std::fmt;

/// Structured error raised from Rust and decoded on the Elixir side.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LuxError {
    /// Value could not be decoded as the expected Elixir type.
    Type {
        expected: String,
        got: String,
    },
    /// Term was valid Elixir but could not be represented in Rust (e.g. bad UTF-8).
    Conversion(String),
    /// Recoverable runtime failure (overflow, division by zero, …).
    Runtime(String),
}

impl LuxError {
    pub fn type_error(expected: impl Into<String>, got: impl Into<String>) -> Self {
        Self::Type {
            expected: expected.into(),
            got: got.into(),
        }
    }

    pub fn conversion(msg: impl Into<String>) -> Self {
        Self::Conversion(msg.into())
    }

    pub fn runtime(msg: impl Into<String>) -> Self {
        Self::Runtime(msg.into())
    }

    /// Tagged reason encoded as `{:type, expected, got}`, `{:conversion, msg}`,
    /// or `{:runtime, msg}` so Elixir can pattern-match without string parsing.
    pub fn reason_tuple<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            Self::Type { expected, got } => (atoms::r#type(), expected, got).encode(env),
            Self::Conversion(msg) => (atoms::conversion(), msg).encode(env),
            Self::Runtime(msg) => (atoms::runtime(), msg).encode(env),
        }
    }
}

impl fmt::Display for LuxError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Type { expected, got } => {
                write!(f, "type error: expected {expected}, got {got}")
            }
            Self::Conversion(msg) => write!(f, "conversion error: {msg}"),
            Self::Runtime(msg) => write!(f, "runtime error: {msg}"),
        }
    }
}

impl std::error::Error for LuxError {}

impl From<LuxError> for rustler::Error {
    fn from(err: LuxError) -> Self {
        rustler::Error::Term(Box::new(EncodableLuxError(err)))
    }
}

/// Wrapper so we can implement `Encoder` without conflicting with orphan rules.
struct EncodableLuxError(LuxError);

impl Encoder for EncodableLuxError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        self.0.reason_tuple(env)
    }
}

pub mod atoms {
    rustler::atoms! {
        ok,
        error,
        r#type,
        conversion,
        runtime,
        nil,
        integer,
        float,
        boolean,
        atom,
        string,
        binary,
        list,
        map,
        tuple,
        pid,
        other,
        unexpected,
    }
}

#[cfg(test)]
mod tests {
    use super::LuxError;

    #[test]
    fn display_type_error() {
        let err = LuxError::type_error("integer", "binary");
        assert_eq!(err.to_string(), "type error: expected integer, got binary");
    }

    #[test]
    fn display_conversion_error() {
        let err = LuxError::conversion("invalid utf-8");
        assert_eq!(err.to_string(), "conversion error: invalid utf-8");
    }

    #[test]
    fn display_runtime_error() {
        let err = LuxError::runtime("division by zero");
        assert_eq!(err.to_string(), "runtime error: division by zero");
    }
}
