pub mod bridge;
pub mod error;
pub mod types;

use bridge::FunctionRegistry;
use error::RustError;
use serde_json::Value;
use std::sync::OnceLock;
use types::LuxValue;

static REGISTRY: OnceLock<FunctionRegistry> = OnceLock::new();

fn get_registry() -> &'static FunctionRegistry {
    REGISTRY.get_or_init(FunctionRegistry::new)
}

/// JSON interface bridging Elixir and Rust
pub fn execute_json(input_json: &str) -> String {
    let parsed: serde_json::Result<Value> = serde_json::from_str(input_json);

    let response = match parsed {
        Ok(Value::Object(map)) => {
            let func_name = map.get("func").and_then(|v| v.as_str()).unwrap_or("");
            let args_val = map.get("args").cloned().unwrap_or(Value::Null);
            let lux_args: LuxValue = args_val.into();

            match get_registry().call(func_name, lux_args) {
                Ok(res) => {
                    let out_val: Value = res.into();
                    serde_json::json!({
                        "status": "ok",
                        "result": out_val
                    })
                }
                Err(err) => serde_json::json!({
                    "status": "error",
                    "error": err
                }),
            }
        }
        Ok(_) => serde_json::json!({
            "status": "error",
            "error": RustError::InvalidArgument("Expected JSON object with 'func' and 'args'".to_string())
        }),
        Err(e) => serde_json::json!({
            "status": "error",
            "error": RustError::Serialization(e.to_string())
        }),
    };

    serde_json::to_string(&response).unwrap_or_else(|_| {
        r#"{"status":"error","error":{"type":"Serialization","message":"Critical serialization failure"}}"#.to_string()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_math_add() {
        let req = r#"{"func":"math.add","args":{"a":10.5,"b":2.5}}"#;
        let res = execute_json(req);
        assert!(res.contains(r#""status":"ok""#));
        assert!(res.contains("13.0"));
    }

    #[test]
    fn test_math_fibonacci() {
        let req = r#"{"func":"math.fibonacci","args":{"n":10}}"#;
        let res = execute_json(req);
        assert!(res.contains(r#""status":"ok""#));
        assert!(res.contains("55"));
    }

    #[test]
    fn test_function_not_found() {
        let req = r#"{"func":"nonexistent","args":{}}"#;
        let res = execute_json(req);
        assert!(res.contains(r#""status":"error""#));
        assert!(res.contains("FunctionNotFound"));
    }
}
