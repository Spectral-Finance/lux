use serde::Serialize;

pub fn convert_type(value: &str, target_type: &str) -> Result<String, String> {
    match target_type {
        "i64" => {
            let n: i64 = value.parse().map_err(|e| format!("Invalid i64: {e}"))?;
            Ok(n.to_string())
        }
        "f64" => {
            let n: f64 = value.parse().map_err(|e| format!("Invalid f64: {e}"))?;
            Ok(n.to_string())
        }
        "bool" => {
            let b: bool = value.parse().map_err(|e| format!("Invalid bool: {e}"))?;
            Ok(b.to_string())
        }
        "json" => {
            let v: serde_json::Value = serde_json::from_str(value)
                .map_err(|e| format!("Invalid JSON: {e}"))?;
            Ok(v.to_string())
        }
        "string" => Ok(value.to_string()),
        _ => Err(format!("Unknown type: {target_type}")),
    }
}

#[derive(Serialize)]
pub struct LuxStruct {
    pub fields: Vec<LuxField>,
}

#[derive(Serialize)]
pub struct LuxField {
    pub name: String,
    pub type_name: String,
    pub value: String,
}

pub fn make_struct(fields: Vec<(String, String)>) -> Result<LuxStruct, String> {
    Ok(LuxStruct {
        fields: fields.into_iter().map(|(name, value)| LuxField {
            name, type_name: "string".into(), value,
        }).collect(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn test_convert_int() { assert_eq!(convert_type("42","i64").unwrap(), "42"); }
    #[test] fn test_convert_float() { assert_eq!(convert_type("3.14","f64").unwrap(), "3.14"); }
    #[test] fn test_convert_bool() { assert_eq!(convert_type("true","bool").unwrap(), "true"); }
    #[test] fn test_convert_json() { assert_eq!(convert_type(r#"{"a":1}"#,"json").unwrap(), r#"{"a":1}"#); }
    #[test] fn test_make_struct() {
        let s = make_struct(vec![("name".into(), "test".into())]).unwrap();
        assert_eq!(s.fields.len(), 1);
    }
    #[test] fn test_unknown_type() { assert!(convert_type("x","unknown").is_err()); }
}
