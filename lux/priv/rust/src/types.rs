//! Owned conversions between Elixir terms and Rust values.
//!
//! Terms are copied into `Converted` so NIFs never retain BEAM pointers
//! after returning to the scheduler.

use rustler::types::map::MapIterator;
use rustler::types::tuple;
use rustler::{Encoder, Env, Term, TermType};
use std::collections::BTreeMap;

use crate::error::LuxError;

#[derive(Debug, Clone, PartialEq)]
pub enum Converted {
    Nil,
    Bool(bool),
    Integer(i64),
    Float(f64),
    Atom(String),
    String(String),
    Binary(Vec<u8>),
    List(Vec<Converted>),
    Tuple(Vec<Converted>),
    Map(BTreeMap<String, Converted>),
}

impl Converted {
    pub fn from_term(term: Term<'_>) -> Result<Self, rustler::Error> {
        match term.get_type() {
            TermType::Atom => {
                if term.is_atom() {
                    if let Ok(b) = term.decode::<bool>() {
                        return Ok(Converted::Bool(b));
                    }
                    let name = term.atom_to_string().unwrap_or_else(|_| "nil".into());
                    if name == "nil" {
                        Ok(Converted::Nil)
                    } else {
                        Ok(Converted::Atom(name))
                    }
                } else {
                    Ok(Converted::Nil)
                }
            }
            TermType::Integer => {
                let n: i64 = term.decode()?;
                Ok(Converted::Integer(n))
            }
            TermType::Float => {
                let n: f64 = term.decode()?;
                Ok(Converted::Float(n))
            }
            TermType::Binary => {
                if let Ok(s) = term.decode::<String>() {
                    Ok(Converted::String(s))
                } else {
                    let bin: rustler::Binary = term.decode()?;
                    Ok(Converted::Binary(bin.as_slice().to_vec()))
                }
            }
            TermType::List => {
                let list: Vec<Term> = term.decode()?;
                let items = list
                    .into_iter()
                    .map(Converted::from_term)
                    .collect::<Result<Vec<_>, _>>()?;
                Ok(Converted::List(items))
            }
            TermType::Map => {
                let mut map = BTreeMap::new();
                if let Some(iter) = MapIterator::new(term) {
                    for (k, v) in iter {
                        let key = match Converted::from_term(k)? {
                            Converted::Atom(s) | Converted::String(s) => s,
                            Converted::Integer(n) => n.to_string(),
                            other => other.type_name().to_string(),
                        };
                        map.insert(key, Converted::from_term(v)?);
                    }
                }
                Ok(Converted::Map(map))
            }
            TermType::Tuple => {
                let terms = tuple::get_tuple(term)?;
                let items = terms
                    .into_iter()
                    .map(Converted::from_term)
                    .collect::<Result<Vec<_>, _>>()?;
                Ok(Converted::Tuple(items))
            }
            other => Err(rustler::Error::Term(Box::new(format!(
                "unsupported term type: {other:?}"
            )))),
        }
    }

    pub fn to_term<'a>(&self, env: Env<'a>) -> Result<Term<'a>, rustler::Error> {
        Ok(match self {
            Converted::Nil => rustler::types::atom::nil().encode(env),
            Converted::Bool(b) => b.encode(env),
            Converted::Integer(n) => n.encode(env),
            Converted::Float(n) => n.encode(env),
            Converted::Atom(s) => {
                rustler::Atom::from_str(env, s)?.encode(env)
            }
            Converted::String(s) => s.encode(env),
            Converted::Binary(b) => {
                let mut owned = rustler::OwnedBinary::new(b.len())
                    .ok_or_else(|| rustler::Error::Term(Box::new("binary alloc failed")))?;
                owned.as_mut_slice().copy_from_slice(b);
                owned.release(env).encode(env)
            }
            Converted::List(items) => {
                let terms: Result<Vec<_>, _> = items.iter().map(|i| i.to_term(env)).collect();
                terms?.encode(env)
            }
            Converted::Tuple(items) => {
                let terms: Result<Vec<_>, _> = items.iter().map(|i| i.to_term(env)).collect();
                let terms = terms?;
                tuple::make_tuple(env, &terms)
            }
            Converted::Map(map) => {
                let mut term = rustler::types::map::map_new(env);
                for (k, v) in map {
                    term = term.map_put(k.encode(env), v.to_term(env)?)?;
                }
                term
            }
        })
    }

    pub fn describe<'a>(&self, env: Env<'a>) -> Result<Term<'a>, rustler::Error> {
        let mut m = rustler::types::map::map_new(env);
        m = m.map_put("type".encode(env), self.type_name().encode(env))?;
        m = m.map_put("value".encode(env), self.to_term(env)?)?;
        Ok(m)
    }

    pub fn type_name(&self) -> &'static str {
        match self {
            Converted::Nil => "nil",
            Converted::Bool(_) => "boolean",
            Converted::Integer(_) => "integer",
            Converted::Float(_) => "float",
            Converted::Atom(_) => "atom",
            Converted::String(_) => "string",
            Converted::Binary(_) => "binary",
            Converted::List(_) => "list",
            Converted::Tuple(_) => "tuple",
            Converted::Map(_) => "map",
        }
    }

    pub fn as_i64(&self) -> Result<i64, LuxError> {
        match self {
            Converted::Integer(n) => Ok(*n),
            other => Err(LuxError::type_error("integer", other.type_name())),
        }
    }

    pub fn as_map(&self) -> Result<&BTreeMap<String, Converted>, LuxError> {
        match self {
            Converted::Map(m) => Ok(m),
            other => Err(LuxError::type_error("map", other.type_name())),
        }
    }

    pub fn map_get(&self, key: &str) -> Result<&Converted, LuxError> {
        self.as_map()?
            .get(key)
            .ok_or_else(|| LuxError::runtime(format!("missing key {key}")))
    }
}

