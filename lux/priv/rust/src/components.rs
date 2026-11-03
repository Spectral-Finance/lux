use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::HashMap;
use std::sync::Arc;
use crate::error::{Result, RustError};
use crate::types::LuxValue;

/// Context passed to native Rust components during invocation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentContext {
    pub execution_id: String,
    pub agent_id: Option<String>,
    pub metadata: HashMap<String, LuxValue>,
    pub timeout_ms: Option<u64>,
}

impl ComponentContext {
    pub fn new(execution_id: &str) -> Self {
        Self {
            execution_id: execution_id.to_string(),
            agent_id: None,
            metadata: HashMap::new(),
            timeout_ms: Some(30_000),
        }
    }
}

/// Trait defining a native Lux Prism in Rust
pub trait LuxPrism: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn input_schema(&self) -> serde_json::Value;
    fn output_schema(&self) -> serde_json::Value;

    fn init(&mut self) -> Result<()> {
        Ok(())
    }

    fn teardown(&mut self) -> Result<()> {
        Ok(())
    }

    fn handler(&self, input: LuxValue, ctx: &ComponentContext) -> Result<LuxValue>;
}

/// Asynchronous trait for long-running or IO-bound Rust Prisms
#[async_trait]
pub trait LuxAsyncPrism: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn input_schema(&self) -> serde_json::Value;
    fn output_schema(&self) -> serde_json::Value;

    async fn handler_async(&self, input: LuxValue, ctx: &ComponentContext) -> Result<LuxValue>;
}

/// Trait defining a native Lux Beam sequence in Rust
pub trait LuxBeam: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn input_schema(&self) -> serde_json::Value;
    fn output_schema(&self) -> serde_json::Value;

    fn run(&self, input: LuxValue, ctx: &ComponentContext) -> Result<LuxValue>;
}

/// Example Native Prism: High Performance Matrix Multiplier
pub struct MatrixMultiplyPrism;

impl LuxPrism for MatrixMultiplyPrism {
    fn name(&self) -> &str {
        "RustMatrixMultiply"
    }

    fn description(&self) -> &str {
        "High-performance SIMD matrix dot product implemented natively in Rust"
    }

    fn input_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "a": {"type": "array", "items": {"type": "number"}},
                "b": {"type": "array", "items": {"type": "number"}}
            },
            "required": ["a", "b"]
        })
    }

    fn output_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "dot_product": {"type": "number"}
            },
            "required": ["dot_product"]
        })
    }

    fn handler(&self, input: LuxValue, _ctx: &ComponentContext) -> Result<LuxValue> {
        if let LuxValue::Map(map) = input {
            let a = map.get("a").and_then(|v| v.as_list()).ok_or_else(|| {
                RustError::InvalidArgument("Missing vector 'a'".to_string())
            })?;
            let b = map.get("b").and_then(|v| v.as_list()).ok_or_else(|| {
                RustError::InvalidArgument("Missing vector 'b'".to_string())
            })?;

            if a.len() != b.len() {
                return Err(RustError::InvalidArgument("Vectors must have identical length".to_string()));
            }

            let mut sum = 0.0;
            for (x, y) in a.iter().zip(b.iter()) {
                let vx = x.as_f64().unwrap_or(0.0);
                let vy = y.as_f64().unwrap_or(0.0);
                sum += vx * vy;
            }

            let mut out = HashMap::new();
            out.insert("dot_product".to_string(), LuxValue::Float(sum));
            Ok(LuxValue::Map(out))
        } else {
            Err(RustError::InvalidArgument("Expected object with 'a' and 'b'".to_string()))
        }
    }
}

/// Central component registry
pub struct ComponentRegistry {
    prisms: HashMap<String, Arc<dyn LuxPrism>>,
}

impl ComponentRegistry {
    pub fn new() -> Self {
        let mut reg = Self {
            prisms: HashMap::new(),
        };
        reg.register_prism(Arc::new(MatrixMultiplyPrism));
        reg
    }

    pub fn register_prism(&mut self, prism: Arc<dyn LuxPrism>) {
        self.prisms.insert(prism.name().to_string(), prism);
    }

    pub fn get_prism(&self, name: &str) -> Option<Arc<dyn LuxPrism>> {
        self.prisms.get(name).cloned()
    }

    pub fn list_prisms(&self) -> Vec<serde_json::Value> {
        self.prisms
            .values()
            .map(|p| {
                json!({
                    "name": p.name(),
                    "description": p.description(),
                    "input_schema": p.input_schema(),
                    "output_schema": p.output_schema()
                })
            })
            .collect()
    }
}
