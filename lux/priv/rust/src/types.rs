//! Bidirectional conversion between Elixir terms and owned Rust values.
//!
//! Conversion never retains pointers into the BEAM heap. Every decoded value
//! is copied into an owned `Converted` tree so it is safe to hold across NIF
//! calls or move onto a dirty scheduler.

use crate::error::{atoms, LuxError};
use rustler::types::atom::Atom;
use rustler::types::tuple;
use rustler::{Binary, Decoder, Encoder, Env, ListIterator, MapIterator, NifResult, Term, TermType};

/// Owned Rust view of an Elixir term.
#[derive(Debug, Clone, PartialEq)]
pub enum Converted {
    Nil,
    Boolean(bool),
    Integer(i64),
    Float(f64),
    Atom(String),
    String(String),
    Binary(Vec<u8>),
    List(Vec<Converted>),
    Map(Vec<(Converted, Converted)>),
    Tuple(Vec<Converted>),
    Pid,
    Other(String),
}

impl Converted {
    /// Decode any Elixir term into an owned Rust value.
    pub fn from_term(term: Term<'_>) -> NifResult<Self> {
        match term.get_type() {
            TermType::Atom => decode_atom(term),
            TermType::Binary => decode_binary(term),
            TermType::EmptyList => Ok(Converted::List(Vec::new())),
            TermType::List => decode_list(term),
            TermType::Map => decode_map(term),
            TermType::Tuple => decode_tuple(term),
            TermType::Pid => Ok(Converted::Pid),
            other => {
                // rustler 0.35+ uses Integer/Float; older builds used Number.
                // Try numeric decode first so both layouts work.
                let label = format!("{other:?}");
                if label.contains("Integer")
                    || label.contains("Float")
                    || label.contains("Number")
                {
                    decode_number(term)
                } else {
                    Ok(Converted::Other(label.to_lowercase()))
                }
            }
        }
    }

    /// Encode back to an Elixir term of the original shape (round-trip).
    pub fn to_term<'a>(&self, env: Env<'a>) -> NifResult<Term<'a>> {
        match self {
            Converted::Nil => Ok(atoms::nil().encode(env)),
            Converted::Boolean(v) => Ok(v.encode(env)),
            Converted::Integer(v) => Ok(v.encode(env)),
            Converted::Float(v) => Ok(v.encode(env)),
            Converted::Atom(name) => {
                let atom = Atom::from_str(env, name).map_err(|_| {
                    rustler::Error::from(LuxError::conversion(format!(
                        "atom name `{name}` is not valid UTF-8 for an atom"
                    )))
                })?;
                Ok(atom.encode(env))
            }
            Converted::String(v) => Ok(v.encode(env)),
            Converted::Binary(bytes) => {
                let mut bin = rustler::OwnedBinary::new(bytes.len()).ok_or_else(|| {
                    rustler::Error::from(LuxError::runtime(
                        "failed to allocate owned binary for encoding",
                    ))
                })?;
                bin.as_mut_slice().copy_from_slice(bytes);
                Ok(bin.release(env).encode(env))
            }
            Converted::List(items) => {
                let encoded: NifResult<Vec<Term<'a>>> =
                    items.iter().map(|item| item.to_term(env)).collect();
                Ok(encoded?.encode(env))
            }
            Converted::Map(pairs) => {
                let mut map = rustler::Term::map_new(env);
                for (k, v) in pairs {
                    map = map
                        .map_put(k.to_term(env)?, v.to_term(env)?)
                        .map_err(|_| {
                            rustler::Error::from(LuxError::conversion(
                                "failed to insert map pair",
                            ))
                        })?;
                }
                Ok(map)
            }
            Converted::Tuple(items) => {
                let encoded: NifResult<Vec<Term<'a>>> =
                    items.iter().map(|item| item.to_term(env)).collect();
                Ok(tuple::make_tuple(env, &encoded?))
            }
            Converted::Pid => Err(LuxError::conversion("cannot re-encode a pid from Rust").into()),
            Converted::Other(kind) => {
                Err(LuxError::conversion(format!("cannot re-encode term of type {kind}")).into())
            }
        }
    }

    pub fn type_name(&self) -> &'static str {
        match self {
            Converted::Nil => "nil",
            Converted::Boolean(_) => "boolean",
            Converted::Integer(_) => "integer",
            Converted::Float(_) => "float",
            Converted::Atom(_) => "atom",
            Converted::String(_) => "string",
            Converted::Binary(_) => "binary",
            Converted::List(_) => "list",
            Converted::Map(_) => "map",
            Converted::Tuple(_) => "tuple",
            Converted::Pid => "pid",
            Converted::Other(_) => "other",
        }
    }

    /// Tagged description: `%{"type" => "integer", "value" => 42}`.
    pub fn describe<'a>(&self, env: Env<'a>) -> NifResult<Term<'a>> {
        let mut map = Term::map_new(env);
        map = map
            .map_put("type".encode(env), self.type_name().encode(env))
            .map_err(|_| rustler::Error::from(LuxError::runtime("failed to build description")))?;

        let value = match self {
            Converted::Nil => atoms::nil().encode(env),
            Converted::Boolean(v) => v.encode(env),
            Converted::Integer(v) => v.encode(env),
            Converted::Float(v) => v.encode(env),
            Converted::Atom(v) => v.encode(env),
            Converted::String(v) => v.encode(env),
            Converted::Binary(v) => v.len().encode(env),
            Converted::List(v) => v.len().encode(env),
            Converted::Map(v) => v.len().encode(env),
            Converted::Tuple(v) => v.len().encode(env),
            Converted::Pid => atoms::pid().encode(env),
            Converted::Other(kind) => kind.encode(env),
        };

        map = map
            .map_put("value".encode(env), value)
            .map_err(|_| rustler::Error::from(LuxError::runtime("failed to build description")))?;
        Ok(map)
    }
}

fn decode_atom(term: Term<'_>) -> NifResult<Converted> {
    if term.decode::<bool>().is_ok() {
        let value: bool = term.decode()?;
        return Ok(Converted::Boolean(value));
    }

    let atom = Atom::from_term(term)?;
    let name = atom
        .to_term(term.get_env())
        .atom_to_string()
        .map_err(|_| rustler::Error::from(LuxError::conversion("atom is not valid UTF-8")))?;

    if name == "nil" {
        Ok(Converted::Nil)
    } else {
        Ok(Converted::Atom(name))
    }
}

fn decode_number(term: Term<'_>) -> NifResult<Converted> {
    if let Ok(v) = i64::decode(term) {
        return Ok(Converted::Integer(v));
    }
    if let Ok(v) = f64::decode(term) {
        return Ok(Converted::Float(v));
    }
    Err(LuxError::type_error("integer or float", "number").into())
}

fn decode_binary(term: Term<'_>) -> NifResult<Converted> {
    let binary = Binary::from_term(term).map_err(|_| {
        rustler::Error::from(LuxError::type_error("binary", term_type_name(term)))
    })?;
    let bytes = binary.as_slice().to_vec();
    match String::from_utf8(bytes.clone()) {
        Ok(s) => Ok(Converted::String(s)),
        Err(_) => Ok(Converted::Binary(bytes)),
    }
}

fn decode_list(term: Term<'_>) -> NifResult<Converted> {
    let iter: ListIterator = term.decode()?;
    let mut items = Vec::new();
    for item in iter {
        items.push(Converted::from_term(item)?);
    }
    Ok(Converted::List(items))
}

fn decode_map(term: Term<'_>) -> NifResult<Converted> {
    let iter = MapIterator::new(term).ok_or_else(|| {
        rustler::Error::from(LuxError::type_error("map", term_type_name(term)))
    })?;
    let mut pairs = Vec::new();
    for (k, v) in iter {
        pairs.push((Converted::from_term(k)?, Converted::from_term(v)?));
    }
    Ok(Converted::Map(pairs))
}

fn decode_tuple(term: Term<'_>) -> NifResult<Converted> {
    let elements = tuple::get_tuple(term).map_err(|_| {
        rustler::Error::from(LuxError::type_error("tuple", term_type_name(term)))
    })?;
    let mut items = Vec::with_capacity(elements.len());
    for item in elements {
        items.push(Converted::from_term(item)?);
    }
    Ok(Converted::Tuple(items))
}

fn term_type_name(term: Term<'_>) -> String {
    format!("{:?}", term.get_type()).to_lowercase()
}

#[cfg(test)]
mod tests {
    use super::Converted;

    #[test]
    fn type_names() {
        assert_eq!(Converted::Integer(1).type_name(), "integer");
        assert_eq!(Converted::Nil.type_name(), "nil");
        assert_eq!(Converted::List(vec![]).type_name(), "list");
    }
}
