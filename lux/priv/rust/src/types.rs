//! Type conversion between Elixir and Rust
//!
//! This module provides the `LuxValue` type which serves as the bridge
//! between Elixir terms and Rust values, enabling seamless data exchange.

use rustler::{Decoder, Encoder, Env, Error, NifResult, Term};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Maximum allowed collection size (lists and maps)
const MAX_COLLECTION_SIZE: usize = 10_000;

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

impl<'a> Decoder<'a> for LuxValue {
    fn decode(term: Term<'a>) -> NifResult<Self> {
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

        // Tuple (convert to list)
        if let Ok(tuple) = rustler::types::tuple::get_tuple(term) {
            if tuple.len() > MAX_COLLECTION_SIZE {
                return Err(Error::BadArg);
            }
            let values: NifResult<Vec<LuxValue>> =
                tuple.into_iter().map(LuxValue::decode).collect();
            return Ok(LuxValue::List(values?));
        }

        // List (with size limit)
        if term.is_list() {
            if let Ok(list) = term.decode::<Vec<Term>>() {
                if list.len() > MAX_COLLECTION_SIZE {
                    return Err(Error::BadArg);
                }
                let values: NifResult<Vec<LuxValue>> =
                    list.into_iter().map(LuxValue::decode).collect();
                return Ok(LuxValue::List(values?));
            }
        }

        // Map (with size limit)
        if term.is_map() {
            if let Ok(map) = term.decode::<HashMap<String, Term>>() {
                if map.len() > MAX_COLLECTION_SIZE {
                    return Err(Error::BadArg);
                }
                let mut result = HashMap::new();
                for (key, value_term) in map {
                    result.insert(key, LuxValue::decode(value_term)?);
                }
                return Ok(LuxValue::Map(result));
            }
            // Try with atom keys
            if let Ok(map) = term.decode::<HashMap<Term, Term>>() {
                if map.len() > MAX_COLLECTION_SIZE {
                    return Err(Error::BadArg);
                }
                let mut result = HashMap::new();
                for (key_term, value_term) in map {
                    let key = if let Ok(s) = key_term.atom_to_string() {
                        s
                    } else if let Ok(s) = key_term.decode::<String>() {
                        s
                    } else {
                        return Err(Error::BadArg);
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
                // Map creation from valid pairs cannot fail
                Term::map_from_pairs(env, &pairs).expect("valid map pairs")
            }
        }
    }
}
