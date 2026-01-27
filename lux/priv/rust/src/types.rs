//! Type conversion between Elixir and Rust
//!
//! This module provides the `LuxValue` type which serves as the bridge
//! between Elixir terms and Rust values, enabling seamless data exchange.

use rustler::{Decoder, Encoder, Env, Error, NifResult, Term};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A value that can be exchanged between Elixir and Rust
///
/// This enum represents all supported types for cross-language communication.
/// It implements both Rustler's encoding/decoding traits and Serde traits
/// for JSON serialization.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum LuxValue {
    /// Null/nil value
    Nil,
    /// Boolean value
    Bool(bool),
    /// Integer value (i64)
    Integer(i64),
    /// Floating point value (f64)
    Float(f64),
    /// String value
    String(String),
    /// List of values
    List(Vec<LuxValue>),
    /// Map of string keys to values
    Map(HashMap<String, LuxValue>),
}

impl Default for LuxValue {
    fn default() -> Self {
        LuxValue::Nil
    }
}

impl<'a> Decoder<'a> for LuxValue {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        // Try to decode in order of specificity

        // Nil
        if term.is_atom() {
            if let Ok(atom) = term.atom_to_string() {
                if atom == "nil" {
                    return Ok(LuxValue::Nil);
                }
                if atom == "true" {
                    return Ok(LuxValue::Bool(true));
                }
                if atom == "false" {
                    return Ok(LuxValue::Bool(false));
                }
                // Other atoms are converted to strings
                return Ok(LuxValue::String(atom));
            }
        }

        // Integer
        if let Ok(n) = term.decode::<i64>() {
            return Ok(LuxValue::Integer(n));
        }

        // Float
        if let Ok(n) = term.decode::<f64>() {
            return Ok(LuxValue::Float(n));
        }

        // String/Binary
        if let Ok(s) = term.decode::<String>() {
            return Ok(LuxValue::String(s));
        }

        // List
        if term.is_list() {
            if let Ok(list) = term.decode::<Vec<Term>>() {
                let values: NifResult<Vec<LuxValue>> =
                    list.into_iter().map(|t| LuxValue::decode(t)).collect();
                return Ok(LuxValue::List(values?));
            }
        }

        // Map
        if term.is_map() {
            if let Ok(map) = term.decode::<HashMap<String, Term>>() {
                let mut result = HashMap::new();
                for (key, value_term) in map {
                    result.insert(key, LuxValue::decode(value_term)?);
                }
                return Ok(LuxValue::Map(result));
            }
            // Try with atom keys
            if let Ok(map) = term.decode::<HashMap<Term, Term>>() {
                let mut result = HashMap::new();
                for (key_term, value_term) in map {
                    let key = if let Ok(s) = key_term.atom_to_string() {
                        s
                    } else if let Ok(s) = key_term.decode::<String>() {
                        s
                    } else {
                        continue;
                    };
                    result.insert(key, LuxValue::decode(value_term)?);
                }
                return Ok(LuxValue::Map(result));
            }
        }

        Err(Error::BadArg)
    }
}

impl Encoder for LuxValue {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            LuxValue::Nil => rustler::types::atom::nil().encode(env),
            LuxValue::Bool(b) => b.encode(env),
            LuxValue::Integer(n) => n.encode(env),
            LuxValue::Float(n) => n.encode(env),
            LuxValue::String(s) => s.encode(env),
            LuxValue::List(list) => {
                let terms: Vec<Term> = list.iter().map(|v| v.encode(env)).collect();
                terms.encode(env)
            }
            LuxValue::Map(map) => {
                let pairs: Vec<(Term, Term)> = map
                    .iter()
                    .map(|(k, v)| (k.encode(env), v.encode(env)))
                    .collect();
                Term::map_from_pairs(env, &pairs).unwrap_or_else(|_| {
                    // Fallback to empty map on error
                    let empty: Vec<(Term, Term)> = vec![];
                    Term::map_from_pairs(env, &empty).unwrap()
                })
            }
        }
    }
}

// Convenient From implementations
impl From<bool> for LuxValue {
    fn from(b: bool) -> Self {
        LuxValue::Bool(b)
    }
}

impl From<i64> for LuxValue {
    fn from(n: i64) -> Self {
        LuxValue::Integer(n)
    }
}

impl From<i32> for LuxValue {
    fn from(n: i32) -> Self {
        LuxValue::Integer(n as i64)
    }
}

impl From<f64> for LuxValue {
    fn from(n: f64) -> Self {
        LuxValue::Float(n)
    }
}

impl From<String> for LuxValue {
    fn from(s: String) -> Self {
        LuxValue::String(s)
    }
}

impl From<&str> for LuxValue {
    fn from(s: &str) -> Self {
        LuxValue::String(s.to_string())
    }
}

impl<T: Into<LuxValue>> From<Vec<T>> for LuxValue {
    fn from(list: Vec<T>) -> Self {
        LuxValue::List(list.into_iter().map(|v| v.into()).collect())
    }
}

impl<T: Into<LuxValue>> From<HashMap<String, T>> for LuxValue {
    fn from(map: HashMap<String, T>) -> Self {
        LuxValue::Map(map.into_iter().map(|(k, v)| (k, v.into())).collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lux_value_from_primitives() {
        assert_eq!(LuxValue::from(42i64), LuxValue::Integer(42));
        assert_eq!(LuxValue::from(3.14f64), LuxValue::Float(3.14));
        assert_eq!(
            LuxValue::from("hello"),
            LuxValue::String("hello".to_string())
        );
        assert_eq!(LuxValue::from(true), LuxValue::Bool(true));
    }

    #[test]
    fn test_lux_value_json_roundtrip() {
        let value = LuxValue::Map(HashMap::from([
            ("name".to_string(), LuxValue::String("test".to_string())),
            ("count".to_string(), LuxValue::Integer(42)),
        ]));

        let json = serde_json::to_string(&value).unwrap();
        let decoded: LuxValue = serde_json::from_str(&json).unwrap();

        assert_eq!(value, decoded);
    }
}
