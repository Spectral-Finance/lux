use rustler::{NifResult, Term};

mod types;
mod crypto;
mod error;

#[rustler::nif]
fn hash_sha256(data: String) -> NifResult<String> {
    let hash = crypto::sha256_hash(data.as_bytes());
    Ok(hex::encode(hash))
}

#[rustler::nif]
fn serialize_json(data: String) -> NifResult<String> {
    let parsed: serde_json::Value =
        serde_json::from_str(&data).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    serde_json::to_string_pretty(&parsed)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
}

#[rustler::nif]
fn deserialize_json(data: String) -> NifResult<String> {
    let parsed: serde_json::Value =
        serde_json::from_str(&data).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    Ok(parsed.to_string())
}

#[rustler::nif]
fn type_to_string(term: Term) -> NifResult<String> {
    let type_str = types::inspect_term_type(term);
    Ok(type_str)
}

#[rustler::nif]
fn add_numbers(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn multiply_numbers(a: f64, b: f64) -> f64 {
    a * b
}

rustler::init!("Elixir.Lux.Native");
