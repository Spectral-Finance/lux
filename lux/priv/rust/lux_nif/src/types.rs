use rustler::{Decoder, Encoder, Env, Error as NifError, NifResult, Term};

/// Tagged value that mirrors the encoding used by `Lux.Rust.FFI`.
///
/// Each variant corresponds to a `%{type: ..., value: ...}` map on the
/// Elixir side so that round-trip conversions can be validated without
/// running the full Elixir FFI module.
#[derive(Debug, Clone)]
pub enum LuxTerm {
    Integer(i64),
    Float(f64),
    Boolean(bool),
    Binary(String),
    Atom(String),
    Nil,
    List(Vec<LuxTerm>),
}

impl LuxTerm {
    /// Converts this `LuxTerm` to its canonical Elixir-side `%{type, value}`
    /// representation encoded into a BEAM `Term`.
    pub fn encode_tagged<'a>(&self, env: Env<'a>) -> Term<'a> {
        use rustler::types::atom;

        match self {
            LuxTerm::Integer(n) => make_tagged(env, "integer", n.encode(env)),
            LuxTerm::Float(f) => make_tagged(env, "float", f.encode(env)),
            LuxTerm::Boolean(b) => make_tagged(env, "boolean", b.encode(env)),
            LuxTerm::Binary(s) => make_tagged(env, "binary", s.encode(env)),
            LuxTerm::Atom(a) => make_tagged(env, "atom", a.encode(env)),
            LuxTerm::Nil => make_tagged(env, "nil", atom::nil().encode(env)),
            LuxTerm::List(items) => {
                let encoded: Vec<Term> = items.iter().map(|t| t.encode_tagged(env)).collect();
                make_tagged(env, "list", encoded.encode(env))
            }
        }
    }
}

fn make_tagged<'a>(env: Env<'a>, type_name: &str, value: Term<'a>) -> Term<'a> {
    let map = Term::map_new(env);
    let type_key = "type".encode(env);
    let value_key = "value".encode(env);
    let type_val = type_name.encode(env);
    map.map_put(type_key, type_val)
        .and_then(|m| m.map_put(value_key, value))
        .unwrap_or_else(|_| rustler::types::atom::error().encode(env))
}

/// Decodes a raw integer `Term` into a `LuxTerm::Integer`.
pub fn decode_integer(term: Term) -> NifResult<LuxTerm> {
    let n: i64 = term.decode()?;
    Ok(LuxTerm::Integer(n))
}

/// Decodes a raw float `Term` into a `LuxTerm::Float`.
pub fn decode_float(term: Term) -> NifResult<LuxTerm> {
    let f: f64 = term.decode()?;
    Ok(LuxTerm::Float(f))
}

/// Decodes a binary `Term` into a `LuxTerm::Binary`.
pub fn decode_binary(term: Term) -> NifResult<LuxTerm> {
    let s: String = term.decode()?;
    Ok(LuxTerm::Binary(s))
}

/// Returns whether an integer value fits within the given signed 8-bit range.
pub fn fits_i8(n: i64) -> bool {
    n >= i8::MIN as i64 && n <= i8::MAX as i64
}

/// Returns whether an integer value fits within the unsigned 8-bit range.
pub fn fits_u8(n: i64) -> bool {
    n >= 0 && n <= u8::MAX as i64
}

/// Returns whether an integer value fits within the signed 32-bit range.
pub fn fits_i32(n: i64) -> bool {
    n >= i32::MIN as i64 && n <= i32::MAX as i64
}
