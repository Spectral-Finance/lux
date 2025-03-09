use rustler::{Atom, Env, Error, NifStruct, ResourceArc, Term, Encoder, NifResult};
use std::sync::Mutex;
use async_trait::async_trait;
use tokio::runtime::Runtime;
use std::fmt;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        not_implemented,
        component_error,
    }
}

mod components;
use components::EchoComponent;

// Component trait that defines the interface for all Lux components
#[async_trait]
pub trait LuxComponent: Send + Sync + fmt::Debug {
    async fn initialize(&self) -> Result<(), Error>;
    async fn process(&self, input: serde_json::Value) -> Result<serde_json::Value, Error>;
    async fn cleanup(&self) -> Result<(), Error>;
}

// Component resource that holds the runtime and component instance
#[derive(Debug)]
pub struct ComponentResource {
    runtime: Mutex<Runtime>,
    component: Box<dyn LuxComponent>,
}

// Component configuration struct that can be passed from Elixir
#[derive(NifStruct, Debug)]
#[module = "Lux.Components.RustConfig"]
pub struct ComponentConfig<'a> {
    pub name: String,
    pub config: Term<'a>,
}

// Initialize the runtime and component
#[rustler::nif]
fn initialize<'a>(env: Env<'a>, config: ComponentConfig<'a>) -> Result<Term<'a>, Error> {
    let runtime = Runtime::new().map_err(|e| Error::Term(Box::new(format!("Runtime error: {}", e))))?;
    
    // Create component instance based on name (to be implemented by specific components)
    let component = create_component(env, &config)?;
    
    // Initialize the component
    runtime.block_on(async {
        component.initialize().await
    })?;
    
    let resource = ResourceArc::new(ComponentResource {
        runtime: Mutex::new(runtime),
        component,
    });
    
    Ok(resource.encode(env))
}

// Process input through the component
#[rustler::nif]
fn process<'a>(env: Env<'a>, resource: ResourceArc<ComponentResource>, input: Term<'a>) -> NifResult<Term<'a>> {
    // Convert input Term to serde_json::Value
    let input_value = term_to_json(env, input)?;
    
    let runtime = &resource.runtime.lock().unwrap();
    let result = runtime.block_on(async {
        resource.component.process(input_value).await
    })?;
    
    // Convert result back to Term
    json_to_term(env, &result)
}

// Cleanup component resources
#[rustler::nif]
fn cleanup(resource: ResourceArc<ComponentResource>) -> NifResult<Atom> {
    let runtime = &resource.runtime.lock().unwrap();
    runtime.block_on(async {
        resource.component.cleanup().await
    })?;
    
    Ok(atoms::ok())
}

// Helper function to create component instances
fn create_component<'a>(env: Env<'a>, config: &ComponentConfig<'a>) -> Result<Box<dyn LuxComponent>, Error> {
    let config_json = term_to_json(env, config.config)?;
    
    match config.name.as_str() {
        "echo" => Ok(Box::new(EchoComponent::new(config_json))),
        _ => Err(Error::Term(Box::new(atoms::not_implemented())))
    }
}

// Helper function to convert Term to serde_json::Value
fn term_to_json<'a>(env: Env<'a>, term: Term<'a>) -> Result<serde_json::Value, Error> {
    if term.is_map() {
        let map: std::collections::HashMap<String, Term> = term.decode()?;
        let mut json_map = serde_json::Map::new();
        for (key, value) in map {
            let value_json = term_to_json(env, value)?;
            json_map.insert(key, value_json);
        }
        Ok(serde_json::Value::Object(json_map))
    } else if term.is_list() {
        let list: Vec<Term> = term.decode().unwrap_or_default();
        let mut json_list = Vec::new();
        for item in list {
            json_list.push(term_to_json(env, item)?);
        }
        Ok(serde_json::Value::Array(json_list))
    } else if term.is_number() {
        if let Ok(n) = term.decode::<i64>() {
            Ok(serde_json::Value::Number(n.into()))
        } else if let Ok(n) = term.decode::<f64>() {
            if let Some(num) = serde_json::Number::from_f64(n) {
                Ok(serde_json::Value::Number(num))
            } else {
                Ok(serde_json::Value::Number(0.into()))
            }
        } else {
            Ok(serde_json::Value::Number(0.into()))
        }
    } else if let Ok(s) = term.decode::<String>() {
        Ok(serde_json::Value::String(s))
    } else if let Ok(b) = term.decode::<bool>() {
        Ok(serde_json::Value::Bool(b))
    } else if term.is_atom() {
        if let Ok(atom_str) = term.atom_to_string() {
            if atom_str == "nil" {
                Ok(serde_json::Value::Null)
            } else {
                Ok(serde_json::Value::String(atom_str))
            }
        } else {
            Ok(serde_json::Value::Null)
        }
    } else {
        Ok(serde_json::Value::Null)
    }
}

// Helper function to convert serde_json::Value to Term
fn json_to_term<'a>(env: Env<'a>, value: &serde_json::Value) -> Result<Term<'a>, Error> {
    match value {
        serde_json::Value::Object(map) => {
            let map_entries: Vec<(String, Term)> = map
                .iter()
                .map(|(k, v)| Ok((k.clone(), json_to_term(env, v)?)))
                .collect::<Result<_, Error>>()?;
            Ok(map_entries.encode(env))
        }
        serde_json::Value::Array(array) => {
            let terms: Result<Vec<Term>, Error> = array.iter().map(|v| json_to_term(env, v)).collect();
            Ok(terms?.encode(env))
        }
        serde_json::Value::String(s) => Ok(s.encode(env)),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(i.encode(env))
            } else if let Some(f) = n.as_f64() {
                Ok(f.encode(env))
            } else {
                Ok(0i64.encode(env))
            }
        }
        serde_json::Value::Bool(b) => Ok(b.encode(env)),
        serde_json::Value::Null => Ok(rustler::types::atom::nil().encode(env)),
    }
}

#[allow(non_local_definitions)]
fn load(env: Env, _: Term) -> bool {
    let _ = rustler::resource!(ComponentResource, env);
    true
}

rustler::init! {
    "Elixir.Lux.Components.Rust",
    load = load
} 