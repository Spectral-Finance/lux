//! Lux Rust Core Library
//! 
//! This module provides the core Rust functionality for the Lux multi-agent framework.
//! It enables cross-language testing and integration with Elixir/Python components.

pub mod test_framework;
pub mod fixtures;
pub mod coverage;
pub mod runner;

pub use test_framework::*;
pub use fixtures::*;
pub use coverage::*;
pub use runner::*;

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Test result from a Rust test execution
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestResult {
    pub name: String,
    pub passed: bool,
    pub duration_ms: u64,
    pub message: Option<String>,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
}

/// Test suite configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestSuiteConfig {
    pub name: String,
    pub fixtures: Vec<String>,
    pub timeout_ms: u64,
    pub parallel: bool,
}

impl Default for TestSuiteConfig {
    fn default() -> Self {
        Self {
            name: "lux-rs".to_string(),
            fixtures: vec![],
            timeout_ms: 30000,
            parallel: true,
        }
    }
}

/// Cross-language test utilities
pub mod cross_language {
    use super::*;
    
    /// Encode test results for Elixir integration
    pub fn encode_results(results: Vec<TestResult>) -> String {
        serde_json::to_string(&results).unwrap_or_else(|_| "[]".to_string())
    }
    
    /// Decode test results from JSON
    pub fn decode_results(json: &str) -> Vec<TestResult> {
        serde_json::from_str(json).unwrap_or_default()
    }
}
