use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A schema definition for validating LuxTypes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Schema {
    pub name: String,
    #[serde(rename = "type")]
    pub schema_type: SchemaType,
    #[serde(default)]
    pub required: Vec<String>,
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum SchemaType {
    #[serde(rename = "primitive")]
    Primitive { name: String },
    #[serde(rename = "struct")]
    Struct { fields: HashMap<String, Schema> },
    #[serde(rename = "enum")]
    Enum { variants: Vec<EnumVariant> },
    #[serde(rename = "list")]
    List { items: Box<Schema> },
    #[serde(rename = "map")]
    Map { key: Box<Schema>, value: Box<Schema> },
    #[serde(rename = "tuple")]
    Tuple { elements: Vec<Schema> },
    #[serde(rename = "optional")]
    Optional { inner: Box<Schema> },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnumVariant {
    pub name: String,
    #[serde(default)]
    pub data: Option<Box<Schema>>,
}

/// Validate a JSON value against a schema
pub fn validate(json: &str, schema_json: &str) -> Result<(), String> {
    let _value: serde_json::Value = serde_json::from_str(json)
        .map_err(|e| format!("Invalid JSON: {e}"))?;
    let _schema: Schema = serde_json::from_str(schema_json)
        .map_err(|e| format!("Invalid schema: {e}"))?;

    // Schema validation logic
    validate_value(&_value, &_schema)
}

fn validate_value(value: &serde_json::Value, schema: &Schema) -> Result<(), String> {
    match &schema.schema_type {
        SchemaType::Primitive { name } => validate_primitive(value, name),
        SchemaType::Struct { fields } => validate_struct(value, fields, &schema.required),
        SchemaType::List { items } => validate_list(value, items),
        SchemaType::Map { key: _, value: val_schema } => validate_map(value, val_schema),
        SchemaType::Optional { inner } => {
            if value.is_null() { Ok(()) } else { validate_value(value, inner) }
        }
        SchemaType::Enum { variants } => validate_enum(value, variants),
        SchemaType::Tuple { elements } => validate_tuple(value, elements),
    }
}

fn validate_primitive(value: &serde_json::Value, type_name: &str) -> Result<(), String> {
    let ok = match type_name {
        "string" => value.is_string(),
        "integer" => value.is_i64() || value.is_u64(),
        "float" | "number" => value.is_number(),
        "boolean" => value.is_boolean(),
        "null" => value.is_null(),
        "any" => true,
        _ => return Err(format!("Unknown primitive: {type_name}")),
    };
    if ok { Ok(()) } else { Err(format!("Expected {type_name}, got {}", json_type(value))) }
}

fn validate_struct(value: &serde_json::Value, fields: &HashMap<String, Schema>, required: &[String]) -> Result<(), String> {
    let obj = value.as_object().ok_or("Expected object")?;
    for req in required {
        if !obj.contains_key(req) {
            return Err(format!("Missing required field: {req}"));
        }
    }
    for (key, field_schema) in fields {
        if let Some(v) = obj.get(key) {
            validate_value(v, field_schema)?;
        }
    }
    Ok(())
}

fn validate_list(value: &serde_json::Value, items: &Schema) -> Result<(), String> {
    let arr = value.as_array().ok_or("Expected array")?;
    for (i, item) in arr.iter().enumerate() {
        validate_value(item, items).map_err(|e| format!("[{i}]: {e}"))?;
    }
    Ok(())
}

fn validate_map(value: &serde_json::Value, val_schema: &Schema) -> Result<(), String> {
    let obj = value.as_object().ok_or("Expected object")?;
    for (k, v) in obj {
        validate_value(v, val_schema).map_err(|e| format!("{k}: {e}"))?;
    }
    Ok(())
}

fn validate_enum(value: &serde_json::Value, variants: &[EnumVariant]) -> Result<(), String> {
    let obj = value.as_object().ok_or("Expected object with 'variant' field")?;
    let variant_name = obj.get("variant")
        .and_then(|v| v.as_str())
        .ok_or("Missing 'variant' field")?;

    let variant = variants.iter().find(|v| v.name == variant_name)
        .ok_or(format!("Unknown variant: {variant_name}"))?;

    if let Some(data_schema) = &variant.data {
        if let Some(data) = obj.get("data") {
            validate_value(data, data_schema)?;
        } else {
            return Err(format!("Variant {variant_name} requires data"));
        }
    }
    Ok(())
}

fn validate_tuple(value: &serde_json::Value, elements: &[Schema]) -> Result<(), String> {
    let arr = value.as_array().ok_or("Expected array for tuple")?;
    if arr.len() != elements.len() {
        return Err(format!("Tuple length mismatch: expected {}, got {}", elements.len(), arr.len()));
    }
    for (i, (item, schema)) in arr.iter().zip(elements).enumerate() {
        validate_value(item, schema).map_err(|e| format!("[{i}]: {e}"))?;
    }
    Ok(())
}

fn json_type(v: &serde_json::Value) -> &'static str {
    match v {
        serde_json::Value::Null => "null",
        serde_json::Value::Bool(_) => "boolean",
        serde_json::Value::Number(_) => "number",
        serde_json::Value::String(_) => "string",
        serde_json::Value::Array(_) => "array",
        serde_json::Value::Object(_) => "object",
    }
}
