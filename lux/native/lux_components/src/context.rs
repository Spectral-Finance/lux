use serde::{Deserialize, Serialize};
use serde_json::Value;

/// The execution context passed to components during handling.
/// Provides access to the execution payload and global states.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Context {
    pub execution_id: String,
    pub step_id: String,
    pub payload: Value,
    pub globals: Value,
}

impl Context {
    pub fn new(execution_id: String, step_id: String, payload: Value) -> Self {
        Self {
            execution_id,
            step_id,
            payload,
            globals: Value::Object(Default::default()),
        }
    }
    
    pub fn get_global(&self, key: &str) -> Option<&Value> {
        self.globals.get(key)
    }
}
