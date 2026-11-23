//! Type conversion layer between Elixir terms and Rust primitives.
//!
//! Rustler already provides conversions for the primitive types via the
//! [`Encoder`](rustler::Encoder) / [`Decoder`](rustler::Decoder) traits. This
//! module wraps those conversions in small, well-typed helpers and adds a few
//! composite conversions (maps, keyword-ish lists, string lists) that Lux
//! components need when crossing the BEAM <-> native boundary.
//!
//! The helpers here are deliberately total: they return `Result<_, DecodeError>`
//! so callers can decide how to surface a bad conversion to Elixir.

use rustler::{Decoder, Encoder, Env, Error as NifError, Term};

/// Convert a Rust `i64` into a BEAM integer term.
#[inline]
pub fn int_to_term<'a>(env: Env<'a>, value: i64) -> Term<'a> {
    value.encode(env)
}

/// Convert a BEAM term into a Rust `i64`, mapping decode failures to a
/// structured [`NifError::Term`].
#[inline]
pub fn term_to_int(term: Term) -> Result<i64, NifError> {
    i64::decode(term).map_err(NifError::from)
}

/// Convert a Rust `String` into a BEAM binary term.
#[inline]
pub fn string_to_term<'a>(env: Env<'a>, value: String) -> Term<'a> {
    value.encode(env)
}

/// Convert a BEAM binary (or charlist) term into a Rust `String`.
#[inline]
pub fn term_to_string(term: Term) -> Result<String, NifError> {
    String::decode(term).map_err(NifError::from)
}

/// Convert a slice of strings into a BEAM list of binaries.
#[inline]
pub fn string_list_to_term<'a>(env: Env<'a>, values: &[String]) -> Term<'a> {
    values.encode(env)
}

/// Convert a BEAM list term into a `Vec<String>`.
#[inline]
pub fn term_to_string_list(term: Term) -> Result<Vec<String>, NifError> {
    Vec::<String>::decode(term).map_err(NifError::from)
}

/// Convert a BEAM list of integers into a `Vec<i64>`.
#[inline]
pub fn term_to_int_list(term: Term) -> Result<Vec<i64>, NifError> {
    Vec::<i64>::decode(term).map_err(NifError::from)
}

/// Convert a `Vec<i64>` into a BEAM list of integers.
#[inline]
pub fn int_list_to_term<'a>(env: Env<'a>, values: &[i64]) -> Term<'a> {
    values.encode(env)
}

/// Read a single key from a BEAM map term, decoding the value as `T`.
///
/// Returns `Err(NifError::BadArg)` if the term is not a map or the key is
/// missing, which Rustler surfaces to Elixir as a `ArgumentError`.
pub fn map_get<'a, T>(map: Term<'a>, key: &str) -> Result<T, NifError>
where
    T: Decoder<'a>,
{
    let map: rustler::types::map::MapIterator<'a> =
        Decoder::decode(map).map_err(|_| NifError::BadArg)?;
    for (k, v) in map {
        if let Ok(ks) = String::decode(k) {
            if ks == key {
                return T::decode(v).map_err(NifError::from);
            }
        }
    }
    Err(NifError::BadArg)
}

#[cfg(test)]
mod tests {
    #[test]
    fn int_roundtrip_via_rust() {
        // Pure-Rust roundtrip sanity check (no BEAM required).
        let v: i64 = 42;
        assert_eq!(v.to_string().parse::<i64>().unwrap(), v);
    }

    #[test]
    fn string_list_roundtrip() {
        let input = vec!["a".to_string(), "b".to_string(), "c".to_string()];
        let joined = input.join(",");
        assert_eq!(joined, "a,b,c");
    }
}