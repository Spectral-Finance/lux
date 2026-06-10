use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Common trait for all Lux components (Prisms and Beams)
pub trait Component: Send + Sync {
    /// Get the component name
    fn name(&self) -> &str;
    
    /// Get the component version
    fn version(&self) -> &str;
    
    /// Get component metadata
    fn metadata(&self) -> &HashMap<String, String>;
    
    /// Validate component configuration
    fn validate(&self) -> Result<(), ComponentError>;
}

/// Error types for component operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ComponentError {
    ValidationError(String),
    ExecutionError(String),
    ConfigurationError(String),
    LifecycleError(String),
    AsyncError(String),
}

impl std::fmt::Display for ComponentError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ComponentError::ValidationError(msg) => write!(f, "Validation error: {}", msg),
            ComponentError::ExecutionError(msg) => write!(f, "Execution error: {}", msg),
            ComponentError::ConfigurationError(msg) => write!(f, "Configuration error: {}", msg),
            ComponentError::LifecycleError(msg) => write!(f, "Lifecycle error: {}", msg),
            ComponentError::AsyncError(msg) => write!(f, "Async error: {}", msg),
        }
    }
}

impl std::error::Error for ComponentError {}

/// Component input/output type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentIO {
    pub data: serde_json::Value,
    pub schema: Option<String>,
}

/// Component configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentConfig {
    pub name: String,
    pub version: String,
    pub metadata: HashMap<String, String>,
    pub settings: serde_json::Value,
}

impl ComponentConfig {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            version: "0.1.0".to_string(),
            metadata: HashMap::new(),
            settings: serde_json::Value::Null,
        }
    }
    
    pub fn with_version(mut self, version: impl Into<String>) -> Self {
        self.version = version.into();
        self
    }
    
    pub fn with_metadata(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.metadata.insert(key.into(), value.into());
        self
    }
}