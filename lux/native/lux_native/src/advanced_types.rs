use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A Lux type definition that can be exchanged between Elixir and Rust.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum LuxType {
    #[serde(rename = "string")]
    String { value: String },
    #[serde(rename = "integer")]
    Integer { value: i64 },
    #[serde(rename = "float")]
    Float { value: f64 },
    #[serde(rename = "boolean")]
    Boolean { value: bool },
    #[serde(rename = "null")]
    Null,
    #[serde(rename = "list")]
    List { items: Vec<LuxType> },
    #[serde(rename = "map")]
    Map { entries: HashMap<String, LuxType> },
    #[serde(rename = "struct")]
    Struct { name: String, fields: HashMap<String, LuxType> },
    #[serde(rename = "enum")]
    Enum { name: String, variant: String, data: Option<Box<LuxType>> },
    #[serde(rename = "tuple")]
    Tuple { elements: Vec<LuxType> },
    #[serde(rename = "binary")]
    Binary { data: String }, // base64 encoded
}

/// Serialize a LuxType to JSON
pub fn serialize(lux_type: &LuxType) -> Result<String, String> {
    serde_json::to_string(lux_type).map_err(|e| e.to_string())
}

/// Deserialize JSON to LuxType
pub fn deserialize(json: &str) -> Result<LuxType, String> {
    serde_json::from_str(json).map_err(|e| e.to_string())
}

/// Convert from a plain JSON value to a LuxType (inference)
pub fn from_json_value(value: &serde_json::Value) -> LuxType {
    match value {
        serde_json::Value::Null => LuxType::Null,
        serde_json::Value::Bool(b) => LuxType::Boolean { value: *b },
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                LuxType::Integer { value: i }
            } else {
                LuxType::Float { value: n.as_f64().unwrap_or(0.0) }
            }
        }
        serde_json::Value::String(s) => LuxType::String { value: s.clone() },
        serde_json::Value::Array(arr) => LuxType::List {
            items: arr.iter().map(from_json_value).collect(),
        },
        serde_json::Value::Object(obj) => LuxType::Map {
            entries: obj.iter().map(|(k, v)| (k.clone(), from_json_value(v))).collect(),
        },
    }
}

/// Convert LuxType back to a plain JSON value
pub fn to_json_value(lux_type: &LuxType) -> serde_json::Value {
    match lux_type {
        LuxType::Null => serde_json::Value::Null,
        LuxType::Boolean { value } => serde_json::Value::Bool(*value),
        LuxType::Integer { value } => serde_json::json!(*value),
        LuxType::Float { value } => serde_json::json!(*value),
        LuxType::String { value } => serde_json::Value::String(value.clone()),
        LuxType::List { items } => {
            serde_json::Value::Array(items.iter().map(to_json_value).collect())
        }
        LuxType::Map { entries } => {
            let obj: serde_json::Map<String, serde_json::Value> =
                entries.iter().map(|(k, v)| (k.clone(), to_json_value(v))).collect();
            serde_json::Value::Object(obj)
        }
        LuxType::Struct { name: _, fields } => {
            let obj: serde_json::Map<String, serde_json::Value> =
                fields.iter().map(|(k, v)| (k.clone(), to_json_value(v))).collect();
            serde_json::Value::Object(obj)
        }
        LuxType::Enum { name: _, variant, data } => {
            match data {
                Some(d) => serde_json::json!({ "variant": variant, "data": to_json_value(d) }),
                None => serde_json::json!({ "variant": variant }),
            }
        }
        LuxType::Tuple { elements } => {
            serde_json::Value::Array(elements.iter().map(to_json_value).collect())
        }
        LuxType::Binary { data } => serde_json::Value::String(data.clone()),
    }
}
