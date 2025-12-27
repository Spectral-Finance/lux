//! Type definitions for Elixir-Rust interop
//!
//! This module defines the value types used for converting between
//! Elixir terms and Rust values.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Representation of Elixir values in Rust
///
/// This enum covers all basic Elixir types that can be passed
/// between Elixir and Rust NIFs.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum RustValue {
    /// Elixir nil
    Nil,
    /// Elixir boolean (true/false)
    Boolean(bool),
    /// Elixir integer
    Integer(i64),
    /// Elixir float
    Float(f64),
    /// Elixir string (binary)
    String(String),
    /// Elixir binary (non-UTF8)
    Binary(Vec<u8>),
    /// Elixir atom
    Atom(String),
    /// Elixir list
    List(Vec<RustValue>),
    /// Elixir map with string keys
    Map(HashMap<String, RustValue>),
    /// Elixir tuple
    Tuple(Vec<RustValue>),
}

impl RustValue {
    /// Check if the value is nil
    pub fn is_nil(&self) -> bool {
        matches!(self, RustValue::Nil)
    }

    /// Try to get as integer
    pub fn as_integer(&self) -> Option<i64> {
        match self {
            RustValue::Integer(i) => Some(*i),
            _ => None,
        }
    }

    /// Try to get as float
    pub fn as_float(&self) -> Option<f64> {
        match self {
            RustValue::Float(f) => Some(*f),
            RustValue::Integer(i) => Some(*i as f64),
            _ => None,
        }
    }

    /// Try to get as string
    pub fn as_string(&self) -> Option<&str> {
        match self {
            RustValue::String(s) => Some(s),
            _ => None,
        }
    }

    /// Try to get as boolean
    pub fn as_boolean(&self) -> Option<bool> {
        match self {
            RustValue::Boolean(b) => Some(*b),
            _ => None,
        }
    }

    /// Try to get as list
    pub fn as_list(&self) -> Option<&Vec<RustValue>> {
        match self {
            RustValue::List(l) => Some(l),
            _ => None,
        }
    }

    /// Try to get as map
    pub fn as_map(&self) -> Option<&HashMap<String, RustValue>> {
        match self {
            RustValue::Map(m) => Some(m),
            _ => None,
        }
    }

    /// Get the type name for error messages
    pub fn type_name(&self) -> &'static str {
        match self {
            RustValue::Nil => "nil",
            RustValue::Boolean(_) => "boolean",
            RustValue::Integer(_) => "integer",
            RustValue::Float(_) => "float",
            RustValue::String(_) => "string",
            RustValue::Binary(_) => "binary",
            RustValue::Atom(_) => "atom",
            RustValue::List(_) => "list",
            RustValue::Map(_) => "map",
            RustValue::Tuple(_) => "tuple",
        }
    }
}

/// Type alias for Elixir values (for clarity in APIs)
pub type ElixirValue = RustValue;

// Conversion traits for common Rust types

impl From<i64> for RustValue {
    fn from(i: i64) -> Self {
        RustValue::Integer(i)
    }
}

impl From<i32> for RustValue {
    fn from(i: i32) -> Self {
        RustValue::Integer(i as i64)
    }
}

impl From<f64> for RustValue {
    fn from(f: f64) -> Self {
        RustValue::Float(f)
    }
}

impl From<f32> for RustValue {
    fn from(f: f32) -> Self {
        RustValue::Float(f as f64)
    }
}

impl From<bool> for RustValue {
    fn from(b: bool) -> Self {
        RustValue::Boolean(b)
    }
}

impl From<String> for RustValue {
    fn from(s: String) -> Self {
        RustValue::String(s)
    }
}

impl From<&str> for RustValue {
    fn from(s: &str) -> Self {
        RustValue::String(s.to_string())
    }
}

impl<T: Into<RustValue>> From<Vec<T>> for RustValue {
    fn from(v: Vec<T>) -> Self {
        RustValue::List(v.into_iter().map(Into::into).collect())
    }
}

impl<T: Into<RustValue>> From<Option<T>> for RustValue {
    fn from(opt: Option<T>) -> Self {
        match opt {
            Some(v) => v.into(),
            None => RustValue::Nil,
        }
    }
}

impl Default for RustValue {
    fn default() -> Self {
        RustValue::Nil
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_type_conversions() {
        assert_eq!(RustValue::from(42i64), RustValue::Integer(42));
        assert_eq!(RustValue::from(3.14f64), RustValue::Float(3.14));
        assert_eq!(RustValue::from(true), RustValue::Boolean(true));
        assert_eq!(
            RustValue::from("hello"),
            RustValue::String("hello".to_string())
        );
    }

    #[test]
    fn test_accessors() {
        let int_val = RustValue::Integer(42);
        assert_eq!(int_val.as_integer(), Some(42));
        assert_eq!(int_val.as_float(), Some(42.0));
        assert_eq!(int_val.as_string(), None);

        let str_val = RustValue::String("hello".to_string());
        assert_eq!(str_val.as_string(), Some("hello"));
        assert_eq!(str_val.as_integer(), None);
    }

    #[test]
    fn test_type_names() {
        assert_eq!(RustValue::Nil.type_name(), "nil");
        assert_eq!(RustValue::Integer(0).type_name(), "integer");
        assert_eq!(RustValue::String("".to_string()).type_name(), "string");
    }
}
