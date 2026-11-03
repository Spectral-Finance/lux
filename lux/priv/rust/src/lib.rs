pub mod bridge;
pub mod components;
pub mod error;
pub mod types;

use bridge::FunctionRegistry;
use components::ComponentRegistry;
use error::RustError;
use serde_json::Value;
use std::sync::OnceLock;
use types::LuxValue;

static REGISTRY: OnceLock<FunctionRegistry> = OnceLock::new();
static COMPONENTS: OnceLock<ComponentRegistry> = OnceLock::new();

fn get_registry() -> &'static FunctionRegistry {
    REGISTRY.get_or_init(FunctionRegistry::new)
}

pub fn get_components() -> &'static ComponentRegistry {
    COMPONENTS.get_or_init(ComponentRegistry::new)
}

/// JSON interface bridging Elixir and Rust
pub fn execute_json(input_json: &str) -> String {
    let parsed: serde_json::Result<Value> = serde_json::from_str(input_json);

    let response = match parsed {
        Ok(Value::Object(map)) => {
            let func_name = map.get("func").and_then(|v| v.as_str()).unwrap_or("");
            let args_val = map.get("args").cloned().unwrap_or(Value::Null);
            let lux_args: LuxValue = args_val.into();

            // Check native components first, then function registry
            if let Some(prism) = get_components().get_prism(func_name) {
                let ctx = components::ComponentContext::new("exec_default");
                match prism.handler(lux_args, &ctx) {
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
            } else {
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
    fn test_native_prism_component() {
        let req = r#"{"func":"RustMatrixMultiply","args":{"a":[1.0, 2.0],"b":[3.0, 4.0]}}"#;
        let res = execute_json(req);
        assert!(res.contains(r#""status":"ok""#));
        assert!(res.contains("11.0"));
    }
}
