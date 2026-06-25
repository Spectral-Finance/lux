//! Error handling framework for Lux Rust integration.

use serde::{Deserialize, Serialize};
use crate::types::ErrorKind;

/// Result type alias for Lux operations.
pub type LuxResult<T> = Result<T, LuxError>;

/// Unified error type for Lux Rust operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuxError {
    pub message: String,
    pub kind: ErrorKind,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub context: Option<String>,
}

impl LuxError {
    pub fn new(message: impl Into<String>, kind: ErrorKind) -> Self {
        Self {
            message: message.into(),
            kind,
            source: None,
            context: None,
        }
    }
    pub fn with_source(mut self, source: impl Into<String>) -> Self {
        self.source = Some(source.into());
        self
    }
    pub fn with_context(mut self, context: impl Into<String>) -> Self {
        self.context = Some(context.into());
        self
    }
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| {
            format!(r#"{{"message":"serialization failed","kind":"{}"}}"#, self.kind)
        })
    }
    pub fn from_json(json: &str) -> Self {
        serde_json::from_str(json).unwrap_or_else(|_| Self {
            message: "failed to deserialize error".to_string(),
            kind: ErrorKind::Unknown,
            source: None,
            context: None,
        })
    }
}

impl std::fmt::Display for LuxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{}] {}", self.kind, self.message)?;
        if let Some(ref source) = self.source {
            write!(f, " (caused by: {})", source)?;
        }
        Ok(())
    }
}

impl std::error::Error for LuxError {}

impl From<std::io::Error> for LuxError {
    fn from(error: std::io::Error) -> Self {
        LuxError::new(error.to_string(), ErrorKind::RuntimeError)
    }
}

impl From<serde_json::Error> for LuxError {
    fn from(error: serde_json::Error) -> Self {
        LuxError::new(error.to_string(), ErrorKind::TypeError)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_json_roundtrip() {
        let err = LuxError::new("test error", ErrorKind::RuntimeError)
            .with_source("original cause")
            .with_context("execution context");
        let json = err.to_json();
        let restored = LuxError::from_json(&json);
        assert_eq!(restored.message, "test error");
        assert_eq!(restored.kind, ErrorKind::RuntimeError);
        assert_eq!(restored.source, Some("original cause".to_string()));
        assert_eq!(restored.context, Some("execution context".to_string()));
    }

    #[test]
    fn test_from_io_error() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
        let lux_err: LuxError = io_err.into();
        assert_eq!(lux_err.kind, ErrorKind::RuntimeError);
    }
}
