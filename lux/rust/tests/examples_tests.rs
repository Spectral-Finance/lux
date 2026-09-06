//! Example tests demonstrating Lux Rust testing patterns

use lux_rs::*;

/// Example: Testing an agent module
#[test]
fn test_agent_creation() {
    let config = sample_agent_config();
    assert!(!config.id.is_empty());
    assert!(!config.model.is_empty());
}

/// Example: Testing message passing
#[test]
fn test_message_serialization() {
    let msg = sample_message();
    let json = serde_json::to_string(&msg).unwrap();
    let parsed: AgentMessage = serde_json::from_str(&json).unwrap();
    assert_eq!(msg.id, parsed.id);
    assert_eq!(msg.content, parsed.content);
}

/// Example: Property-based test pattern
#[test]
fn test_config_validation() {
    let config = sample_agent_config();
    
    // Validate config constraints
    assert!(config.max_tokens > 0);
    assert!(config.max_tokens <= 128000);
    assert!(config.temperature >= 0.0);
    assert!(config.temperature <= 2.0);
}

/// Example: Async test pattern
#[tokio::test]
async fn test_async_fixture_access() {
    let container = FixtureContainer::new();
    assert!(container.get::<AgentConfig>("nonexistent").is_none());
}
