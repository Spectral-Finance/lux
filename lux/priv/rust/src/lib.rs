mod types;
mod crypto;
mod error;

use rustler::{Encoder, Env, Error, NifResult, Term};

use types::{LuxValue, LuxMap, LuxList};
use error::LuxNativeError;

rustler::init!("Elixir.Lux.Native", [add, multiply, hash_sha256, hash_keccak256, hex_encode, hex_decode, json_parse, json_encode, lux_type_of, map_merge, sort_list]);

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn multiply(a: i64, b: i64) -> i64 {
    a * b
}

#[rustler::nif]
fn hash_sha256(data: String) -> String {
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    let result = hasher.finalize();
    hex::encode(result)
}

#[rustler::nif]
fn hash_keccak256(data: String) -> String {
    use sha3::{Keccak256, Digest};
    let mut hasher = Keccak256::new();
    hasher.update(data.as_bytes());
    let result = hasher.finalize();
    hex::encode(result)
}

#[rustler::nif]
fn hex_encode(data: String) -> String {
    hex::encode(data.as_bytes())
}

#[rustler::nif]
fn hex_decode(data: String) -> Result<String, Error> {
    match hex::decode(&data) {
        Ok(bytes) => Ok(String::from_utf8_lossy(&bytes).to_string()),
        Err(_) => Err(Error::Term(Box::new("invalid_hex"))),
    }
}

#[rustler::nif]
fn json_parse(json_str: String) -> Result<String, Error> {
    serde_json::from_str::<serde_json::Value>(&json_str)
        .map(|v| v.to_string())
        .map_err(|e| Error::Term(Box::new(format!("json_parse_error: {}", e))))
}

#[rustler::nif]
fn json_encode(json_str: String) -> String {
    json_str
}

#[rustler::nif]
fn lux_type_of<'a>(env: Env<'a>, value: Term<'a>) -> Term<'a> {
    let type_str = if value.is_atom() {
        "atom"
    } else if value.is_binary() {
        "binary"
    } else if value.is_number() {
        "number"
    } else if value.is_list() {
        "list"
    } else if value.is_map() {
        "map"
    } else if value.is_pid() {
        "pid"
    } else {
        "unknown"
    };

    type_str.encode(env)
}

#[rustler::nif]
fn map_merge<'a>(env: Env<'a>, map1: Term<'a>, map2: Term<'a>) -> Result<Term<'a>, Error> {
    let mut result: Vec<(Term, Term)> = Vec::new();

    if let Ok(iter) = rustler::types::map::map_from_term_iter(map1) {
        for (k, v) in iter {
            result.push((k, v));
        }
    }

    if let Ok(iter) = rustler::types::map::map_from_term_iter(map2) {
        for (k, v) in iter {
            result.retain(|(rk, _)| *rk != k);
            result.push((k, v));
        }
    }

    Ok(rustler::types::map::map_from_pairs(env, result))
}

#[rustler::nif]
fn sort_list<'a>(env: Env<'a>, list: Term<'a>) -> Result<Term<'a>, Error> {
    let mut items: Vec<Term> = Vec::new();

    if let Ok(iter) = list.decode::<Vec<Term>>() {
        items = iter;
    }

    items.sort_by(|a, b| {
        let a_str = format!("{:?}", a);
        let b_str = format!("{:?}", b);
        a_str.cmp(&b_str)
    });

    Ok(items.encode(env))
}
