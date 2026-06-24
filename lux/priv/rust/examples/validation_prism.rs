use lux_rust_components::{ComponentKind, LuxComponent, LuxError, LuxPrism};
use serde_json::{json, Value};

pub struct ValidationPrism;

impl LuxComponent for ValidationPrism {
    fn name(&self) -> &'static str {
        "ValidationPrism"
    }

    fn kind(&self) -> ComponentKind {
        ComponentKind::Prism
    }

    fn handle(&self, input: Value) -> Result<Value, LuxError> {
        let valid = input.get("value").is_some();
        Ok(json!({
            "valid": valid,
            "errors": if valid { Vec::<String>::new() } else { vec!["missing value".to_string()] }
        }))
    }
}

impl LuxPrism for ValidationPrism {}
