//! Test Fixtures Module
//! 
//! Provides reusable test fixtures and helpers for Lux Rust tests.

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// A shared fixture container for tests
pub struct FixtureContainer {
    fixtures: HashMap<String, Arc<RwLock<dyn std::any::Any + Send + Sync>>>,
}

impl Default for FixtureContainer {
    fn default() -> Self {
        Self::new()
    }
}

impl FixtureContainer {
    pub fn new() -> Self {
        Self {
            fixtures: HashMap::new(),
        }
    }
    
    /// Register a fixture
    pub fn register<T: Send + Sync + 'static>(&mut self, name: &str, value: T) {
        self.fixtures.insert(
            name.to_string(),
            Arc::new(RwLock::new(value)),
        );
    }
    
    /// Get a fixture by name
    pub fn get<T: Send + Sync + 'static>(&self, name: &str) -> Option<Arc<RwLock<T>>> {
        self.fixtures.get(name).map(|arc| {
            Arc::clone(arc).downcast::<RwLock<T>>().ok()
        }).flatten()
    }
}

/// Common test fixtures for Lux

/// Create a sample agent configuration fixture
pub fn sample_agent_config() -> AgentConfig {
    AgentConfig {
        id: "test-agent-1".to_string(),
        name: "Test Agent".to_string(),
        model: "gpt-4".to_string(),
        max_tokens: 2048,
        temperature: 0.7,
    }
}

/// Create a sample message fixture  
pub fn sample_message() -> AgentMessage {
    AgentMessage {
        id: "msg-001".to_string(),
        sender: "test-agent".to_string(),
        content: "Hello, Lux!".to_string(),
        timestamp: chrono_lite_now(),
    }
}

/// Agent configuration
#[derive(Debug, Clone)]
pub struct AgentConfig {
    pub id: String,
    pub name: String,
    pub model: String,
    pub max_tokens: u32,
    pub temperature: f32,
}

/// Agent message
#[derive(Debug, Clone)]
pub struct AgentMessage {
    pub id: String,
    pub sender: String,
    pub content: String,
    pub timestamp: u64,
}

/// Simple timestamp helper (avoid external deps for fixtures)
fn chrono_lite_now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_fixture_container() {
        let mut container = FixtureContainer::new();
        container.register("config", sample_agent_config());
        
        let config = container.get::<AgentConfig>("config");
        assert!(config.is_some());
    }
    
    #[test]
    fn test_sample_agent_config() {
        let config = sample_agent_config();
        assert_eq!(config.id, "test-agent-1");
        assert_eq!(config.model, "gpt-4");
    }
    
    #[test]
    fn test_sample_message() {
        let msg = sample_message();
        assert_eq!(msg.sender, "test-agent");
        assert_eq!(msg.content, "Hello, Lux!");
    }
}
