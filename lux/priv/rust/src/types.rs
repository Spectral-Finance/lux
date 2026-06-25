//! Type definitions for Lux Rust core.

use serde::{Deserialize, Serialize};

/// Represents a Lux value that can be passed across the FFI boundary.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", content = "value")]
pub enum LuxValue {
    Nil,
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    List(Vec<LuxValue>),
    Map(Vec<(String, LuxValue)>),
}

impl LuxValue {
    pub fn nil() -> Self { LuxValue::Nil }
    pub fn bool(v: bool) -> Self { LuxValue::Bool(v) }
    pub fn int(v: i64) -> Self { LuxValue::Int(v) }
    pub fn float(v: f64) -> Self { LuxValue::Float(v) }
    pub fn str(v: impl Into<String>) -> Self { LuxValue::Str(v.into()) }

    /// Converts the LuxValue to a JSON string.
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "null".to_string())
    }

    /// Parses a JSON string into a LuxValue.
    pub fn from_json(json: &str) -> Result<Self, String> {
        serde_json::from_str(json).map_err(|e| e.to_string())
    }
}

/// Represents an error returned from Rust code.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LuxError {
    pub message: String,
    pub kind: ErrorKind,
    pub context: Option<String>,
}

impl LuxError {
    pub fn new(message: impl Into<String>, kind: ErrorKind) -> Self {
        LuxError {
            message: message.into(),
            kind,
            context: None,
        }
    }
    pub fn with_context(mut self, context: impl Into<String>) -> Self {
        self.context = Some(context.into());
        self
    }
}

impl std::fmt::Display for ErrorKind {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ErrorKind::TypeError => write!(f, "type_error"),
            ErrorKind::RuntimeError => write!(f, "runtime_error"),
            ErrorKind::FfiError => write!(f, "ffi_error"),
            ErrorKind::NotFound => write!(f, "not_found"),
            ErrorKind::Unknown => write!(f, "unknown"),
        }
    }
}

impl std::fmt::Display for LuxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{}] {}", self.kind, self.message)
    }
}

impl std::error::Error for LuxError {}

/// Categorization of Lux errors.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ErrorKind {
    TypeError,
    RuntimeError,
    FfiError,
    NotFound,
    Unknown,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lux_value_serde() {
        let value = LuxValue::Str("hello".to_string());
        let json = value.to_json();
        let parsed = LuxValue::from_json(&json).unwrap();
        assert_eq!(parsed, value);
    }

    #[test]
    fn test_lux_value_list() {
        let list = LuxValue::List(vec![LuxValue::Int(1), LuxValue::Int(2), LuxValue::Int(3)]);
        let json = list.to_json();
        let parsed = LuxValue::from_json(&json).unwrap();
        assert_eq!(parsed, list);
    }

    #[test]
    fn test_lux_value_map() {
        let map = LuxValue::Map(vec![
            ("key".to_string(), LuxValue::Str("value".to_string())),
        ]);
        let json = map.to_json();
        let parsed = LuxValue::from_json(&json).unwrap();
        assert_eq!(parsed, map);
    }

    #[test]
    fn test_lux_error_display() {
        let err = LuxError::new("something failed", ErrorKind::RuntimeError);
        assert_eq!(format!("{}", err), "[runtime_error] something failed");
    }
}
