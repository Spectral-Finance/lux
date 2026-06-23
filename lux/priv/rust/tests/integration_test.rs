//! Integration tests for Lux Rust components.

use lux_rust::version;

#[test]
fn test_version_integration() {
    assert!(!version().is_empty());
}
