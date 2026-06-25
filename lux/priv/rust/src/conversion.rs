//! Type conversion layer between Elixir and Rust.

use crate::types::{LuxValue, ErrorKind};
use crate::error::{LuxError, LuxResult};

/// Converts a JSON value to a LuxValue.
pub fn json_to_lux_value(json: &serde_json::Value) -> LuxResult<LuxValue> {
    match json {
        serde_json::Value::Null => Ok(LuxValue::Nil),
        serde_json::Value::Bool(b) => Ok(LuxValue::Bool(*b)),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(LuxValue::Int(i))
            } else if let Some(f) = n.as_f64() {
                Ok(LuxValue::Float(f))
            } else {
                Err(LuxError::new("cannot convert number", ErrorKind::TypeError))
            }
        }
        serde_json::Value::String(s) => Ok(LuxValue::Str(s.clone())),
        serde_json::Value::Array(arr) => {
            let mut items = Vec::with_capacity(arr.len());
            for v in arr { items.push(json_to_lux_value(v)?); }
            Ok(LuxValue::List(items))
        }
        serde_json::Value::Object(map) => {
            let mut pairs = Vec::with_capacity(map.len());
            for (k, v) in map { pairs.push((k.clone(), json_to_lux_value(v)?)); }
            Ok(LuxValue::Map(pairs))
        }
    }
}

/// Converts a LuxValue to a JSON value.
pub fn lux_value_to_json(value: &LuxValue) -> serde_json::Value {
    match value {
        LuxValue::Nil => serde_json::Value::Null,
        LuxValue::Bool(b) => serde_json::Value::Bool(*b),
        LuxValue::Int(i) => serde_json::Value::Number(serde_json::Number::from(*i)),
        LuxValue::Float(f) => {
            serde_json::Number::from_f64(*f).map(serde_json::Value::Number).unwrap_or(serde_json::Value::Null)
        }
        LuxValue::Str(s) => serde_json::Value::String(s.clone()),
        LuxValue::List(items) => serde_json::Value::Array(items.iter().map(lux_value_to_json).collect()),
        LuxValue::Map(pairs) => {
            let mut obj = serde_json::Map::new();
            for (k, v) in pairs { obj.insert(k.clone(), lux_value_to_json(v)); }
            serde_json::Value::Object(obj)
        }
    }
}

/// Performs numeric addition on two LuxValues.
pub fn lux_add(a: &LuxValue, b: &LuxValue) -> LuxResult<LuxValue> {
    match (a, b) {
        (LuxValue::Int(x), LuxValue::Int(y)) => Ok(LuxValue::Int(x + y)),
        (LuxValue::Float(x), LuxValue::Float(y)) => Ok(LuxValue::Float(x + y)),
        (LuxValue::Int(x), LuxValue::Float(y)) => Ok(LuxValue::Float((*x as f64) + y)),
        (LuxValue::Float(x), LuxValue::Int(y)) => Ok(LuxValue::Float(x + (*y as f64))),
        _ => Err(LuxError::new("cannot add these types", ErrorKind::TypeError)),
    }
}

/// Performs string concatenation on two LuxValues.
pub fn lux_concat(a: &LuxValue, b: &LuxValue) -> LuxResult<LuxValue> {
    match (a, b) {
        (LuxValue::Str(s1), LuxValue::Str(s2)) => Ok(LuxValue::Str(format!("{}{}", s1, s2))),
        (LuxValue::Str(s1), LuxValue::Int(i)) => Ok(LuxValue::Str(format!("{}{}", s1, i))),
        (LuxValue::Int(i), LuxValue::Str(s2)) => Ok(LuxValue::Str(format!("{}{}", i, s2))),
        _ => Err(LuxError::new("cannot concatenate these types", ErrorKind::TypeError)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_json_to_lux_null() {
        assert_eq!(json_to_lux_value(&serde_json::json!(null)).unwrap(), LuxValue::Nil);
    }

    #[test]
    fn test_json_to_lux_int() {
        assert_eq!(json_to_lux_value(&serde_json::json!(42)).unwrap(), LuxValue::Int(42));
    }

    #[test]
    fn test_json_to_lux_string() {
        assert_eq!(json_to_lux_value(&serde_json::json!("hello")).unwrap(), LuxValue::Str("hello".to_string()));
    }

    #[test]
    fn test_json_to_lux_array() {
        let json = serde_json::json!([1, "two", true, null]);
        let value = json_to_lux_value(&json).unwrap();
        match value {
            LuxValue::List(items) => assert_eq!(items.len(), 4),
            _ => panic!("expected List"),
        }
    }

    #[test]
    fn test_roundtrip() {
        let original = LuxValue::Map(vec![
            ("x".to_string(), LuxValue::Int(10)),
            ("y".to_string(), LuxValue::Str("test".to_string())),
        ]);
        let json = lux_value_to_json(&original);
        let back = json_to_lux_value(&json).unwrap();
        assert_eq!(back, original);
    }

    #[test]
    fn test_add_integers() {
        assert_eq!(lux_add(&LuxValue::Int(10), &LuxValue::Int(32)).unwrap(), LuxValue::Int(42));
    }

    #[test]
    fn test_concat_strings() {
        assert_eq!(
            lux_concat(&LuxValue::Str("hello".to_string()), &LuxValue::Str(" world".to_string())).unwrap(),
            LuxValue::Str("hello world".to_string())
        );
    }

    #[test]
    fn test_add_type_error() {
        assert!(lux_add(&LuxValue::Str("x".to_string()), &LuxValue::Int(1)).is_err());
    }
}
