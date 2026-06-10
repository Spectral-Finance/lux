// Rust Component System for Lux

/// Trait for Lux components (Prisms and Beams)
pub trait LuxComponent: Send + Sync {
    /// Get the component name
    fn name(&self) -> &str;
    
    /// Initialize the component
    fn initialize(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        Ok(())
    }
    
    /// Execute the component's main logic
    async fn execute(&mut self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        Ok(serde_json::Value::Null)
    }
    
    /// Clean up resources when component is dropped
    fn cleanup(&mut self) {}
    
    /// Component lifecycle management
    fn on_mount(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        Ok(())
    }
    
    fn on_unmount(&mut self) {}
}

/// Prism component trait
pub trait Prism: LuxComponent {
    /// Process input and return output
    fn process(&self, input: serde_json::Value) -> Result<serde_json::Value, Box<dyn std::error::Error>>;
}

/// Beam component trait  
pub trait Beam {
    /// Execute a workflow with the given input
    fn execute(&self, input: serde_json::Value) -> Result<serde_json::Value, Box<dyn std::error::Error>>;
}

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

/// Base component trait implementation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Component {
    pub name: String,
    pub metadata: HashMap<String, String>,
}

impl LuxComponent for Component {
    fn name(&self) -> &str {
        &self.name
    }
    
    fn initialize(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // Default implementation - can be overridden by specific components
        Ok(())
    }
    
    fn cleanup(&mut self) {
        // Default cleanup implementation
    }
}

impl Component {
    pub fn new(name: &str) -> Self {
        Component {
            name: name.to_string(),
            metadata: HashMap::new(),
        }
    }
    
    pub fn with_metadata(mut self, key: &str, value: &str) -> Self {
        self.metadata.insert(key.to_string(), value.to_string());
        self
    }
}

/// Async component execution trait
#[async_trait::async_trait]
pub trait AsyncComponent {
    async fn execute(&mut self) -> Result<(), Box<dyn std::error::Error>>;
    fn name(&self) -> &str;
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_component_creation() {
        let mut component = Component::new("test_component");
        component.with_metadata("version", "1.0");
        assert!(!component.metadata.is_empty());
    }
}