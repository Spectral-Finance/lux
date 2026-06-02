mod types;
mod crypto;
mod error;
mod component;

use std::sync::Mutex;
use once_cell::sync::Lazy;

use rustler::{Encoder, Env, Error, NifResult, Term};

use component::{Component, BTreeRegistry, ComponentMeta, PrismInput, PrismOutput, Prism};

#[derive(Debug, Clone)]
struct RegisteredComponent {
    meta: ComponentMeta,
    handler_code: String,
    execute_code: String,
}

impl Component for RegisteredComponent {
    fn meta(&self) -> ComponentMeta { self.meta.clone() }
    fn init(&mut self) {}
    fn shutdown(&mut self) {}
    fn is_initialized(&self) -> bool { true }
    fn name(&self) -> &str { &self.meta.name }
    fn kind(&self) -> &str { &self.meta.kind }
}

static COMPONENT_REGISTRY: Lazy<Mutex<BTreeRegistry<RegisteredComponent>>> =
    Lazy::new(|| Mutex::new(BTreeRegistry::new()));

rustler::init!("Elixir.Lux.Native");

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

#[rustler::nif]
fn rust_eval(_code: String, _variables: String, _handler: String) -> Result<String, Error> {
    Ok(serde_json::to_string(&serde_json::json!({
        "status": "ok",
        "message": "Rust eval called"
    })).unwrap())
}

#[rustler::nif]
fn rust_register_component(def_json: String) -> Result<bool, Error> {
    let def: serde_json::Value = serde_json::from_str(&def_json)
        .map_err(|e| Error::Term(Box::new(format!("parse_error: {}", e))))?;

    let name = def["name"].as_str().unwrap_or("unknown").to_string();
    let kind = def["kind"].as_str().unwrap_or("unknown").to_string();

    let meta = ComponentMeta {
        name: name.clone(),
        kind: kind.clone(),
        version: def["version"].as_str().unwrap_or("0.1.0").to_string(),
        description: def["description"].as_str().unwrap_or("").to_string(),
    };

    let comp = RegisteredComponent {
        meta,
        handler_code: def["handler"].as_str().unwrap_or("").to_string(),
        execute_code: def["execute"].as_str().unwrap_or("").to_string(),
    };

    let mut registry = COMPONENT_REGISTRY.lock().unwrap();
    Ok(registry.register(comp))
}

#[rustler::nif]
fn rust_execute_component(component: String, input_json: String) -> Result<String, Error> {
    let registry = COMPONENT_REGISTRY.lock().unwrap();

    let parts: Vec<&str> = component.splitn(2, ':').collect();
    let name = parts.last().unwrap_or(&"");
    let _kind = parts.first().unwrap_or(&"");

    match registry.get(name) {
        Some(_comp) => {
            Ok(serde_json::to_string(&serde_json::json!({
                "status": "ok",
                "component": component,
                "input": serde_json::from_str::<serde_json::Value>(&input_json).unwrap_or(serde_json::Value::Null),
                "result": format!("Executed {}", component)
            })).unwrap())
        }
        None => Err(Error::Term(Box::new(format!("component_not_found: {}", name)))),
    }
}

#[rustler::nif]
fn rust_list_components(kind: String) -> Result<String, Error> {
    let registry = COMPONENT_REGISTRY.lock().unwrap();
    let components = registry.list_by_kind(&kind);
    let metas: Vec<serde_json::Value> = components.iter().map(|c| {
        let meta = c.meta();
        serde_json::json!({
            "name": meta.name,
            "kind": meta.kind,
            "version": meta.version,
            "description": meta.description,
            "handler_code": &c.handler_code,
            "execute_code": &c.execute_code,
        })
    }).collect();
    serde_json::to_string(&metas)
        .map_err(|e| Error::Term(Box::new(format!("serialize_error: {}", e))))
}

#[rustler::nif]
fn rust_unregister_component(_kind: String, name: String) -> bool {
    let mut registry = COMPONENT_REGISTRY.lock().unwrap();
    registry.unregister(&name)
}

#[rustler::nif]
fn rust_component_info() -> Result<String, Error> {
    let registry = COMPONENT_REGISTRY.lock().unwrap();
    let mut info = serde_json::Map::new();

    for kind in &["prism", "beam", "lens"] {
        let count = registry.list_by_kind(kind).len();
        info.insert(kind.to_string(), serde_json::Value::Number(serde_json::Number::from(count)));
    }

    serde_json::to_string(&info)
        .map_err(|e| Error::Term(Box::new(format!("serialize_error: {}", e))))
}

#[rustler::nif]
fn rust_component_init(_kind: String, name: String) -> Result<String, Error> {
    let mut registry = COMPONENT_REGISTRY.lock().unwrap();
    match registry.get_mut(&name) {
        Some(comp) => {
            comp.init();
            Ok("ok".to_string())
        }
        None => Err(Error::Term(Box::new(format!("not_found: {}", name)))),
    }
}

#[rustler::nif]
fn rust_component_shutdown(_kind: String, name: String) -> Result<String, Error> {
    let mut registry = COMPONENT_REGISTRY.lock().unwrap();
    match registry.get_mut(&name) {
        Some(comp) => {
            comp.shutdown();
            Ok("ok".to_string())
        }
        None => Err(Error::Term(Box::new(format!("not_found: {}", name)))),
    }
}

#[rustler::nif]
fn rust_component_count(kind: String) -> usize {
    let registry = COMPONENT_REGISTRY.lock().unwrap();
    registry.list_by_kind(&kind).len()
}
