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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_string() {
        assert!(validate(r#""hello""#, "string").is_ok());
        assert!(validate("42", "string").is_err());
    }

    #[test]
    fn test_validate_integer() {
        assert!(validate("42", "integer").is_ok());
        assert!(validate("3.14", "integer").is_err());
        assert!(validate(r#""hello""#, "integer").is_err());
    }

    #[test]
    fn test_validate_number() {
        assert!(validate("42", "number").is_ok());
        assert!(validate("3.14", "number").is_ok());
        assert!(validate(r#""hello""#, "number").is_err());
    }

    #[test]
    fn test_validate_boolean() {
        assert!(validate("true", "boolean").is_ok());
        assert!(validate("false", "boolean").is_ok());
        assert!(validate("42", "boolean").is_err());
    }

    #[test]
    fn test_validate_null() {
        assert!(validate("null", "null").is_ok());
        assert!(validate("42", "null").is_err());
    }

    #[test]
    fn test_validate_array() {
        assert!(validate("[1,2,3]", "array").is_ok());
        assert!(validate("42", "array").is_err());
    }

    #[test]
    fn test_validate_object() {
        assert!(validate(r#"{"a":1}"#, "object").is_ok());
        assert!(validate("[1]", "object").is_err());
    }

    #[test]
    fn test_validate_any() {
        assert!(validate("42", "any").is_ok());
        assert!(validate(r#""hello""#, "any").is_ok());
        assert!(validate("null", "any").is_ok());
    }

    #[test]
    fn test_validate_unknown_type() {
        assert!(validate("42", "foobar").is_err());
    }

    #[test]
    fn test_validate_invalid_json() {
        assert!(validate("not json", "string").is_err());
    }
}
