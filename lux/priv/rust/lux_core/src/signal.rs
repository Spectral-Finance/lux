//! Signal types — the Rust counterpart to `Lux.Signal` on the Elixir side.
//!
//! A [`Signal`] is the smallest piece of structured data exchanged between
//! Lux agents. It carries a schema identifier, a payload, and free-form
//! metadata. The Rust representation is intentionally minimal so it can be
//! serialised across the BEAM/NIF boundary without pulling in heavyweight
//! dependencies.

use std::collections::HashMap;

/// A single signal exchanged between agents.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Signal {
    /// Identifier of the schema this signal conforms to (e.g. `"chat.message"`).
    pub schema_id: String,
    /// Stringified payload. Higher layers are responsible for decoding.
    pub payload: String,
    /// Free-form key/value metadata (sender id, trace id, etc.).
    pub metadata: HashMap<String, String>,
}

impl Signal {
    /// Builds a new [`Signal`] with empty metadata.
    ///
    /// # Examples
    ///
    /// ```
    /// use lux_core::signal::Signal;
    ///
    /// let s = Signal::new("chat.message", "hello");
    /// assert_eq!(s.schema_id, "chat.message");
    /// assert!(s.metadata.is_empty());
    /// ```
    pub fn new(schema_id: impl Into<String>, payload: impl Into<String>) -> Self {
        Self {
            schema_id: schema_id.into(),
            payload: payload.into(),
            metadata: HashMap::new(),
        }
    }

    /// Inserts a metadata key/value pair and returns the modified signal,
    /// enabling a fluent builder style:
    ///
    /// ```
    /// use lux_core::signal::Signal;
    ///
    /// let s = Signal::new("chat.message", "hi").with_meta("sender", "alice");
    /// assert_eq!(s.metadata.get("sender").map(String::as_str), Some("alice"));
    /// ```
    #[must_use]
    pub fn with_meta(
        mut self,
        key: impl Into<String>,
        value: impl Into<String>,
    ) -> Self {
        self.metadata.insert(key.into(), value.into());
        self
    }

    /// Returns `true` if the signal carries no payload bytes.
    pub fn is_empty(&self) -> bool {
        self.payload.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_signal_has_no_metadata() {
        let s = Signal::new("a", "b");
        assert_eq!(s.schema_id, "a");
        assert_eq!(s.payload, "b");
        assert!(s.metadata.is_empty());
        assert!(!s.is_empty());
    }

    #[test]
    fn with_meta_is_chainable() {
        let s = Signal::new("a", "b")
            .with_meta("k1", "v1")
            .with_meta("k2", "v2");
        assert_eq!(s.metadata.len(), 2);
        assert_eq!(s.metadata["k1"], "v1");
        assert_eq!(s.metadata["k2"], "v2");
    }

    #[test]
    fn empty_payload_is_detected() {
        assert!(Signal::new("a", "").is_empty());
    }

    #[test]
    fn signals_are_value_equal() {
        let a = Signal::new("x", "y").with_meta("k", "v");
        let b = Signal::new("x", "y").with_meta("k", "v");
        assert_eq!(a, b);
    }
}
