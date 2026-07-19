use rustler::{NifResult, Term};

mod types;
mod crypto;
mod error;
mod cargo;
mod ty;
mod test_runner;
mod component;

#[rustler::nif]
fn hash_sha256(data: String) -> NifResult<String> {
    Ok(hex::encode(crypto::sha256_hash(data.as_bytes())))
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
    Ok(types::inspect_term_type(term))
}

#[rustler::nif]
fn add_numbers(a: i64, b: i64) -> i64 { a + b }

#[rustler::nif]
fn multiply_numbers(a: f64, b: f64) -> f64 { a * b }

// --- Cargo Management (#100) ---
#[rustler::nif]
fn cargo_generate_toml(name: String, version: String, deps: Vec<(String, String)>) -> NifResult<String> {
    let mut config = cargo::CargoConfig::new(&name, &version);
    for (dn, dv) in deps { config.add_dependency(&dn, &dv); }
    config.to_toml_string().map_err(|e| rustler::Error::Term(Box::new(e)))
}

#[rustler::nif]
fn cargo_resolve_deps(toml_content: String) -> NifResult<Vec<(String, String)>> {
    cargo::resolve_dependencies(&toml_content).map_err(|e| rustler::Error::Term(Box::new(e)))
}

// --- Type System (#101) ---
#[rustler::nif]
fn type_serialize(value: String, target_type: String) -> NifResult<String> {
    let result = ty::convert_type(&value, &target_type)
        .map_err(|e| rustler::Error::Term(Box::new(e)))?;
    Ok(result)
}

#[rustler::nif]
fn type_make_struct(fields: Vec<(String, String)>) -> NifResult<String> {
    let s = ty::make_struct(fields)
        .map_err(|e| rustler::Error::Term(Box::new(e)))?;
    serde_json::to_string(&s).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
}

// --- Testing Framework (#102) ---
#[rustler::nif]
fn test_parse_and_run(test_code: String) -> NifResult<String> {
    let result = test_runner::run_test(&test_code)
        .map_err(|e| rustler::Error::Term(Box::new(e)))?;
    Ok(result)
}

#[rustler::nif]
fn test_generate_fixture(name: String, data: String) -> NifResult<String> {
    test_runner::generate_fixture(&name, &data)
        .map_err(|e| rustler::Error::Term(Box::new(e)))
}

// --- Component System (#103) ---
#[rustler::nif]
fn component_register(name: String, config_json: String) -> NifResult<String> {
    let result = component::register_component(&name, &config_json)
        .map_err(|e| rustler::Error::Term(Box::new(e)))?;
    Ok(result)
}

rustler::init!("Elixir.Lux.Native");
