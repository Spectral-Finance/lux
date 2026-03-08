use serde_json::Value;
use crate::error::LuxError;

/// Supported type descriptors for validation
const VALID_TYPES: &[&str] = &[
    "string", "integer", "float", "number", "boolean", "null",
    "array", "object", "any",
];

/// Validate a JSON string against a type descriptor
pub fn validate(input: &str, type_name: &str) -> Result<(), LuxError> {
    let value: Value = serde_json::from_str(input)
        .map_err(|e| LuxError::ParseError(e.to_string()))?;

    match type_name {
        "string" => match value {
            Value::String(_) => Ok(()),
            _ => Err(LuxError::TypeError { expected: "string".into(), got: type_of(&value) }),
        },
        "integer" => match value {
            Value::Number(n) if n.is_i64() || n.is_u64() => Ok(()),
            _ => Err(LuxError::TypeError { expected: "integer".into(), got: type_of(&value) }),
        },
        "float" | "number" => match value {
            Value::Number(_) => Ok(()),
            _ => Err(LuxError::TypeError { expected: type_name.into(), got: type_of(&value) }),
        },
        "boolean" => match value {
            Value::Bool(_) => Ok(()),
            _ => Err(LuxError::TypeError { expected: "boolean".into(), got: type_of(&value) }),
        },
        "null" => match value {
            Value::Null => Ok(()),
            _ => Err(LuxError::TypeError { expected: "null".into(), got: type_of(&value) }),
        },
        "array" => match value {
            Value::Array(_) => Ok(()),
            _ => Err(LuxError::TypeError { expected: "array".into(), got: type_of(&value) }),
        },
        "object" => match value {
            Value::Object(_) => Ok(()),
            _ => Err(LuxError::TypeError { expected: "object".into(), got: type_of(&value) }),
        },
        "any" => Ok(()),
        _ => Err(LuxError::UnknownType(type_name.into())),
    }
}

fn type_of(value: &Value) -> String {
    match value {
        Value::Null => "null",
        Value::Bool(_) => "boolean",
        Value::Number(n) if n.is_i64() || n.is_u64() => "integer",
        Value::Number(_) => "float",
        Value::String(_) => "string",
        Value::Array(_) => "array",
        Value::Object(_) => "object",
    }.into()
}

/// List all supported type names
pub fn supported_types() -> &'static [&'static str] {
    VALID_TYPES
}
