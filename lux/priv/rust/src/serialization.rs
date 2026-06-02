use crate::types::SerializedValue;

pub fn json_encode(json_str: &str) -> Result<String, String> {
    let parsed: serde_json::Value = serde_json::from_str(json_str)
        .map_err(|e| format!("json_parse_error: {}", e))?;

    Ok(parsed.to_string())
}

pub fn json_decode_pretty(json_str: &str) -> Result<String, String> {
    let parsed: serde_json::Value = serde_json::from_str(json_str)
        .map_err(|e| format!("json_parse_error: {}", e))?;

    serde_json::to_string_pretty(&parsed)
        .map_err(|e| format!("serialize_error: {}", e))
}

pub fn validate_json(json_str: &str) -> Result<String, String> {
    match serde_json::from_str::<serde_json::Value>(json_str) {
        Ok(v) => Ok(serde_json::to_string(&serde_json::json!({
            "valid": true,
            "kind": type_of_json(&v)
        })).unwrap()),
        Err(e) => Ok(serde_json::to_string(&serde_json::json!({
            "valid": false,
            "error": format!("{}", e)
        })).unwrap()),
    }
}

fn type_of_json(value: &serde_json::Value) -> &str {
    match value {
        serde_json::Value::Null => "null",
        serde_json::Value::Bool(_) => "boolean",
        serde_json::Value::Number(_) => "number",
        serde_json::Value::String(_) => "string",
        serde_json::Value::Array(_) => "array",
        serde_json::Value::Object(_) => "object",
    }
}

pub fn serialize_to_json(data: &str, format: &str, type_hint: Option<&str>) -> SerializedValue {
    SerializedValue {
        format: format.to_string(),
        data: data.to_string(),
        type_hint: type_hint.map(|s| s.to_string()),
    }
}

pub fn deserialize_value(data: &str, format: &str) -> Result<String, String> {
    match format {
        "json" => {
            serde_json::from_str::<serde_json::Value>(data)
                .map(|v| v.to_string())
                .map_err(|e| format!("deserialize_error: {}", e))
        }
        _ => Err(format!("unsupported_format: {}", format)),
    }
}

pub fn compact_json(json_str: &str) -> String {
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(json_str) {
        v.to_string()
    } else {
        json_str.to_string()
    }
}

pub fn sort_json_keys(json_str: &str) -> Result<String, String> {
    let map: serde_json::Map<String, serde_json::Value> = serde_json::from_str(json_str)
        .map_err(|e| format!("json_parse_error: {}", e))?;

    let mut sorted: Vec<(String, serde_json::Value)> = map.into_iter().collect();
    sorted.sort_by(|a, b| a.0.cmp(&b.0));

    let sorted_map: serde_json::Map<String, serde_json::Value> = sorted.into_iter().collect();
    serde_json::to_string(&sorted_map)
        .map_err(|e| format!("serialize_error: {}", e))
}

pub fn extract_types_from_json(json_str: &str) -> Result<String, String> {
    let value: serde_json::Value = serde_json::from_str(json_str)
        .map_err(|e| format!("json_parse_error: {}", e))?;

    let types = infer_types(&value);

    serde_json::to_string(&types)
        .map_err(|e| format!("serialize_error: {}", e))
}

fn infer_types(value: &serde_json::Value) -> serde_json::Value {
    match value {
        serde_json::Value::Object(map) => {
            let mut fields = serde_json::Map::new();
            for (k, v) in map {
                fields.insert(k.clone(), infer_types(v));
            }
            serde_json::Value::Object(fields)
        }
        serde_json::Value::Array(arr) => {
            let inferred: Vec<serde_json::Value> = arr.iter().map(infer_types).collect();
            serde_json::Value::Array(inferred)
        }
        serde_json::Value::Null => serde_json::Value::String("nil".into()),
        serde_json::Value::Bool(_) => serde_json::Value::String("bool".into()),
        serde_json::Value::Number(_) => serde_json::Value::String("number".into()),
        serde_json::Value::String(_) => serde_json::Value::String("String".into()),
    }
}

pub fn deep_merge_into(base_json: &str, overlay_json: &str) -> Result<String, String> {
    let mut base: serde_json::Value = serde_json::from_str(base_json)
        .map_err(|e| format!("base_parse_error: {}", e))?;
    let overlay: serde_json::Value = serde_json::from_str(overlay_json)
        .map_err(|e| format!("overlay_parse_error: {}", e))?;

    deep_merge(&mut base, &overlay);

    serde_json::to_string(&base)
        .map_err(|e| format!("serialize_error: {}", e))
}

fn deep_merge(base: &mut serde_json::Value, overlay: &serde_json::Value) {
    match (base, overlay) {
        (serde_json::Value::Object(ref mut b), serde_json::Value::Object(o)) => {
            for (k, v) in o {
                if b.contains_key(k) {
                    deep_merge(b.get_mut(k).unwrap(), v);
                } else {
                    b.insert(k.clone(), v.clone());
                }
            }
        }
        (b, o) => *b = o.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_json_encode_valid() {
        let result = json_encode(r#"{"key":"value"}"#).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["key"], "value");
    }

    #[test]
    fn test_json_encode_invalid() {
        let result = json_encode("{invalid}");
        assert!(result.is_err());
    }

    #[test]
    fn test_validate_json_valid() {
        let result = validate_json(r#"{"a":1}"#).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["valid"], true);
        assert_eq!(parsed["kind"], "object");
    }

    #[test]
    fn test_validate_json_invalid() {
        let result = validate_json("{bad}").unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["valid"], false);
    }

    #[test]
    fn test_compact_json() {
        let result = compact_json(r#"{"a":  1, "b":2}"#);
        assert_eq!(result, r#"{"a":1,"b":2}"#);
    }

    #[test]
    fn test_sort_json_keys() {
        let result = sort_json_keys(r#"{"b":1,"a":2}"#).unwrap();
        assert_eq!(result, r#"{"a":2,"b":1}"#);
    }

    #[test]
    fn test_extract_types() {
        let result = extract_types_from_json(r#"{"name":"Alice","age":30,"active":true}"#).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["name"], "String");
        assert_eq!(parsed["age"], "number");
        assert_eq!(parsed["active"], "bool");
    }

    #[test]
    fn test_deep_merge() {
        let base = r#"{"a":1,"b":{"x":1}}"#;
        let overlay = r#"{"b":{"y":2},"c":3}"#;
        let result = deep_merge_into(base, overlay).unwrap();
        let merged: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(merged["a"], 1);
        assert_eq!(merged["b"]["x"], 1);
        assert_eq!(merged["b"]["y"], 2);
        assert_eq!(merged["c"], 3);
    }
}
