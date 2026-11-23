//! Error handling framework for the Lux Rust core.
//!
//! Every fallible NIF returns a Rust `Result<T, LuxError>`. Rustler converts
//! `Err(LuxError)` into an Elixir `{:error, reason}` tuple (or raises for
//! truly exceptional cases), giving Elixir callers a uniform, pattern-matchable
//! error contract.
//!
//! ## Error taxonomy
//!
//! * [`LuxError::InvalidArgument`] – caller passed a value the core cannot use.
//! * [`LuxError::Decode`]          – a BEAM term could not be decoded.
//! * [`LuxError::Encode`]          – a Rust value could not be encoded.
//! * [`LuxError::Panic`]           – a caught panic (memory-safe boundary).
//! * [`LuxError::Internal`]        – any other internal failure.
//!
//! Each variant carries a human-readable message and an optional structured
//! detail map so Elixir code can log/telemetry the failure precisely.

use rustler::{Encoder, Env, Term};

/// The structured error type returned by all fallible core operations.
#[derive(Debug, Clone, PartialEq)]
pub enum LuxError {
    /// A required argument was missing or had the wrong shape.
    InvalidArgument { message: String, detail: Option<String> },
    /// A BEAM term could not be decoded into the expected Rust type.
    Decode { message: String },
    /// A Rust value could not be encoded into a BEAM term.
    Encode { message: String },
    /// A panic was caught at the FFI boundary and converted to an error.
    Panic { message: String },
    /// Any other internal failure.
    Internal { message: String },
}

impl LuxError {
    /// Construct an `InvalidArgument` error.
    pub fn invalid_argument(message: impl Into<String>) -> Self {
        LuxError::InvalidArgument { message: message.into(), detail: None }
    }

    /// Construct an `InvalidArgument` error with structured detail.
    pub fn invalid_argument_detail(message: impl Into<String>, detail: impl Into<String>) -> Self {
        LuxError::InvalidArgument { message: message.into(), detail: Some(detail.into()) }
    }

    /// Construct an `Internal` error.
    pub fn internal(message: impl Into<String>) -> Self {
        LuxError::Internal { message: message.into() }
    }

    /// The stable atom identifying the error class, e.g. `:invalid_argument`.
    pub fn kind(&self) -> &'static str {
        match self {
            LuxError::InvalidArgument { .. } => "invalid_argument",
            LuxError::Decode { .. } => "decode",
            LuxError::Encode { .. } => "encode",
            LuxError::Panic { .. } => "panic",
            LuxError::Internal { .. } => "internal",
        }
    }

    /// The human-readable message.
    pub fn message(&self) -> &str {
        match self {
            LuxError::InvalidArgument { message, .. }
            | LuxError::Decode { message }
            | LuxError::Encode { message }
            | LuxError::Panic { message }
            | LuxError::Internal { message } => message,
        }
    }
}

impl std::fmt::Display for LuxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.kind(), self.message())
    }
}

impl std::error::Error for LuxError {}

impl From<rustler::Error> for LuxError {
    fn from(err: rustler::Error) -> Self {
        match err {
            rustler::Error::BadArg => LuxError::InvalidArgument {
                message: "bad argument".to_string(),
                detail: None,
            },
            rustler::Error::Atom(s) => LuxError::Decode { message: format!("atom error: {s}") },
            rustler::Error::RaiseAtom(s) => LuxError::Internal { message: format!("raise: {s}") },
            rustler::Error::RaiseTerm(_) => LuxError::Internal { message: "raise term".to_string() },
            rustler::Error::Term(_) => LuxError::Internal { message: "term error".to_string() },
        }
    }
}

/// Encode a `LuxError` as the *reason* term (a map
/// `%{kind: atom, message: string, detail: string | nil}`).
///
/// Note: this does **not** wrap the result in an `{:error, _}` tuple. Rustler's
/// `Encoder for Result<T, E>` already turns `Err(e)` into `{:error, e.encode(env)}`,
/// so encoding the bare reason here yields the single, correct
/// `{:error, %{kind: ..., message: ..., detail: ...}}` shape on the Elixir side.
/// (Wrapping here as well would double-wrap into `{:error, {:error, reason}}`.)
impl Encoder for LuxError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        use rustler::types::atom::{self, Atom};

        let kind = Atom::from_str(env, self.kind())
            .map(|a| a.to_term(env))
            .unwrap_or_else(|_| atom::error().to_term(env));
        let message = self.message().encode(env);
        let detail = match self {
            LuxError::InvalidArgument { detail: Some(d), .. } => d.encode(env),
            _ => atom::nil().to_term(env),
        };

        let key_kind = Atom::from_str(env, "kind").unwrap().to_term(env);
        let key_message = Atom::from_str(env, "message").unwrap().to_term(env);
        let key_detail = Atom::from_str(env, "detail").unwrap().to_term(env);

        // Build the reason map: %{kind: ..., message: ..., detail: ...}
        rustler::types::map::map_new(env)
            .map_put(key_kind, kind)
            .and_then(|m| m.map_put(key_message, message))
            .and_then(|m| m.map_put(key_detail, detail))
            .unwrap_or_else(|_| atom::nil().to_term(env))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_kind_is_stable() {
        assert_eq!(LuxError::invalid_argument("x").kind(), "invalid_argument");
        assert_eq!(LuxError::internal("y").kind(), "internal");
    }

    #[test]
    fn error_display_includes_kind() {
        let e = LuxError::invalid_argument("bad input");
        assert_eq!(format!("{e}"), "invalid_argument: bad input");
    }

    #[test]
    fn from_rustler_badarg() {
        let e: LuxError = rustler::Error::BadArg.into();
        assert_eq!(e.kind(), "invalid_argument");
    }
}