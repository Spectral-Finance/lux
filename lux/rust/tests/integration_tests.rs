//! Integration tests for Lux Rust
//! 
//! These tests verify the integration between Rust and Elixir components.

use lux_rs::*;

#[test]
fn test_test_framework_basics() {
    let mut runner = LuxTestRunner::new(TestSuiteConfig::default());
    
    let result = runner.run_test("basic_test", || Ok(()));
    assert!(result.passed);
    assert_eq!(result.name, "basic_test");
}

#[test]
fn test_test_framework_failure() {
    let mut runner = LuxTestRunner::new(TestSuiteConfig::default());
    
    let result = runner.run_test("failing_test", || Err("Intentional failure".to_string()));
    assert!(!result.passed);
    assert!(result.message.is_some());
}

#[test]
fn test_fixtures_sample_agent() {
    let config = sample_agent_config();
    assert_eq!(config.id, "test-agent-1");
    assert!(config.max_tokens > 0);
}

#[test]
fn test_fixtures_sample_message() {
    let msg = sample_message();
    assert!(!msg.id.is_empty());
    assert!(!msg.content.is_empty());
}

#[test]
fn test_coverage_basic() {
    let tracker = CoverageTracker::new();
    let report = tracker.report();
    
    assert_eq!(report.total_lines, 0);
    assert_eq!(report.coverage_percentage, 100.0);
}

#[test]
fn test_cross_language_encoding() {
    let results = vec![
        TestResult {
            name: "test1".to_string(),
            passed: true,
            duration_ms: 100,
            message: None,
            stdout: None,
            stderr: None,
        },
    ];
    
    let json = cross_language::encode_results(results.clone());
    let decoded = cross_language::decode_results(&json);
    
    assert_eq!(decoded.len(), 1);
    assert_eq!(decoded[0].name, "test1");
}
