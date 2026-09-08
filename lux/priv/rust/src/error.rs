//! Typed errors that never panic across the NIF boundary.

use rustler::{types::atom::Atom, Encoder, Env, Term};

rustler::atoms! {
    ok,
    error,
    type_error,
    conversion,
    runtime,
    nif_not_loaded,
}

pub mod atoms {
    pub use super::{conversion, error, ok, runtime, type_error};
}

#[derive(Debug, Clone)]
pub enum LuxError {
    Type { expected: String, got: String },
    Conversion(String),
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

    pub fn reason_tuple<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            LuxError::Type { expected, got } => {
                (atoms::type_error(), expected.as_str(), got.as_str()).encode(env)
            }
            LuxError::Conversion(msg) => (atoms::conversion(), msg.as_str()).encode(env),
            LuxError::Runtime(msg) => (atoms::runtime(), msg.as_str()).encode(env),
        }
    }
}

impl From<LuxError> for rustler::Error {
    fn from(err: LuxError) -> Self {
        rustler::Error::Term(Box::new(err.to_string()))
    }
}

impl std::fmt::Display for LuxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LuxError::Type { expected, got } => {
                write!(f, "type error: expected {expected}, got {got}")
            }
            LuxError::Conversion(msg) => write!(f, "conversion error: {msg}"),
            LuxError::Runtime(msg) => write!(f, "runtime error: {msg}"),
        }
    }
}

#[allow(dead_code)]
pub fn atom_ok() -> Atom {
    atoms::ok()
}
