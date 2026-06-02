mod types;
mod crypto;
mod error;
mod type_mapping;
mod serialization;

#[cfg(feature = "nif")]
use rustler::{Encoder, Env, Error, NifResult, Term};

#[cfg(feature = "nif")]
rustler::init!("Elixir.Lux.Native");

#[cfg(feature = "nif")]
#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn multiply(a: i64, b: i64) -> i64 {
    a * b
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn hash_sha256(data: String) -> String {
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    let result = hasher.finalize();
    hex::encode(result)
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn hash_keccak256(data: String) -> String {
    use sha3::{Keccak256, Digest};
    let mut hasher = Keccak256::new();
    hasher.update(data.as_bytes());
    let result = hasher.finalize();
    hex::encode(result)
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn hex_encode(data: String) -> String {
    hex::encode(data.as_bytes())
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn hex_decode(data: String) -> Result<String, Error> {
    match hex::decode(&data) {
        Ok(bytes) => Ok(String::from_utf8_lossy(&bytes).to_string()),
        Err(_) => Err(Error::Term(Box::new("invalid_hex"))),
    }
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn json_parse(json_str: String) -> Result<String, Error> {
    serde_json::from_str::<serde_json::Value>(&json_str)
        .map(|v| v.to_string())
        .map_err(|e| Error::Term(Box::new(format!("json_parse_error: {}", e))))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn json_encode(json_str: String) -> String {
    json_str
}

#[cfg(feature = "nif")]
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

#[cfg(feature = "nif")]
#[rustler::nif]
fn map_merge<'a>(env: Env<'a>, map1: Term<'a>, map2: Term<'a>) -> Result<Term<'a>, Error> {
    let mut result: Vec<(Term, Term)> = Vec::new();

    if let Ok(iter) = map1.decode::<Vec<(Term, Term)>>() {
        result = iter;
    }

    if let Ok(iter) = map2.decode::<Vec<(Term, Term)>>() {
        for (k, v) in iter {
            result.retain(|(rk, _)| *rk != k);
            result.push((k, v));
        }
    }

    Ok(result.encode(env))
}

#[cfg(feature = "nif")]
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

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_map_elixir_to_rust(elixir_type: String) -> String {
    type_mapping::map_elixir_to_rust_type(&elixir_type)
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_map_rust_to_elixir(rust_type: String) -> String {
    type_mapping::map_rust_to_elixir_type(&rust_type)
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_get_standard_mappings() -> Vec<crate::types::TypeMapping> {
    type_mapping::get_standard_mappings()
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_check_compatibility(elixir_type: String, rust_type: String) -> bool {
    type_mapping::check_compatibility(&elixir_type, &rust_type)
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_validate_schema(schema_json: String) -> Result<String, Error> {
    type_mapping::validate_schema(&schema_json)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_define_struct(name: String, kind: String, fields_json: String) -> Result<String, Error> {
    type_mapping::define_struct(&name, &kind, &fields_json)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn type_define_enum(name: String, variants_json: String, discriminant_type: String) -> Result<String, Error> {
    type_mapping::define_enum(&name, &variants_json, &discriminant_type)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_json_encode(value_json: String) -> Result<String, Error> {
    serialization::json_encode(&value_json)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_json_decode_pretty(value_json: String) -> Result<String, Error> {
    serialization::json_decode_pretty(&value_json)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_validate_json(value_json: String) -> Result<String, Error> {
    serialization::validate_json(&value_json)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_serialize_to_json(data: String, format: String, type_hint: Option<String>) -> crate::types::SerializedValue {
    serialization::serialize_to_json(&data, &format, type_hint.as_deref())
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_deserialize_value(data: String, format: String) -> Result<String, Error> {
    serialization::deserialize_value(&data, &format)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_compact_json(json_str: String) -> String {
    serialization::compact_json(&json_str)
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_sort_json_keys(json_str: String) -> Result<String, Error> {
    serialization::sort_json_keys(&json_str)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_extract_types_from_json(json_str: String) -> Result<String, Error> {
    serialization::extract_types_from_json(&json_str)
        .map_err(|e| Error::Term(Box::new(e)))
}

#[cfg(feature = "nif")]
#[rustler::nif]
fn serde_deep_merge_into(base_json: String, overlay_json: String) -> Result<String, Error> {
    serialization::deep_merge_into(&base_json, &overlay_json)
        .map_err(|e| Error::Term(Box::new(e)))
}
