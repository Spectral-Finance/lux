//! Test Framework Module
//! 
//! Provides a comprehensive testing framework for Rust code in Lux,
//! including test runners, assertions, and integration utilities.

use std::time::{Duration, Instant};
use super::TestResult;

/// Custom test runner for Lux Rust tests
pub struct LuxTestRunner {
    config: super::TestSuiteConfig,
    results: Vec<TestResult>,
}

impl LuxTestRunner {
    pub fn new(config: super::TestSuiteConfig) -> Self {
        Self {
            config,
            results: Vec::new(),
        }
    }
    
    /// Run a single test case
    pub fn run_test<F>(&mut self, name: &str, test_fn: F) -> TestResult
    where
        F: FnOnce() -> Result<(), String>,
    {
        let start = Instant::now();
        let result = test_fn();
        let duration = start.elapsed();
        
        let (passed, message) = match result {
            Ok(()) => (true, None),
            Err(e) => (false, Some(e)),
        };
        
        TestResult {
            name: name.to_string(),
            passed,
            duration_ms: duration.as_millis() as u64,
            message,
            stdout: None,
            stderr: None,
        }
    }
    
    /// Run multiple tests
    pub fn run_tests<F, I>(&mut self, tests: I) -> Vec<TestResult>
    where
        F: FnOnce() -> Result<(), String>,
        I: IntoIterator<Item = (String, F)>,
    {
        tests.into_iter()
            .map(|(name, test_fn)| self.run_test(&name, test_fn))
            .collect()
    }
    
    /// Get all results
    pub fn results(&self) -> &[TestResult] {
        &self.results
    }
    
    /// Get summary statistics
    pub fn summary(&self) -> TestSummary {
        let total = self.results.len();
        let passed = self.results.iter().filter(|r| r.passed).count();
        let failed = total - passed;
        let total_duration: u64 = self.results.iter().map(|r| r.duration_ms).sum();
        
        TestSummary {
            total,
            passed,
            failed,
            total_duration_ms: total_duration,
        }
    }
}

/// Test summary statistics
#[derive(Debug, Clone)]
pub struct TestSummary {
    pub total: usize,
    pub passed: usize,
    pub failed: usize,
    pub total_duration_ms: u64,
}

/// Custom assertions for Lux tests
pub mod assertions {
    /// Assert two values are equal
    pub fn assert_eq<T: PartialEq>(left: T, right: T, msg: &str) -> Result<(), String> {
        if left == right {
            Ok(())
        } else {
            Err(format!("Assertion failed: {} (left: {:?}, right: {:?})", msg, left, right))
        }
    }
    
    /// Assert a condition is true
    pub fn assert_true(condition: bool, msg: &str) -> Result<(), String> {
        if condition {
            Ok(())
        } else {
            Err(format!("Assertion failed: {}", msg))
        }
    }
    
    /// Assert a value is some
    pub fn assert_some<T>(opt: Option<T>, msg: &str) -> Result<T, String> {
        opt.ok_or_else(|| format!("Assertion failed: expected Some, got None: {}", msg))
    }
    
    /// Assert a value is none
    pub fn assert_none<T>(opt: Option<T>, msg: &str) -> Result<(), String> {
        if opt.is_none() {
            Ok(())
        } else {
            Err(format!("Assertion failed: expected None, got Some: {}", msg))
        }
    }
}

/// Property-based testing helpers
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_runner_creates_result() {
        let mut runner = LuxTestRunner::new(super::super::TestSuiteConfig::default());
        let result = runner.run_test("simple_test", || Ok(()));
        
        assert!(result.passed);
        assert_eq!(result.name, "simple_test");
    }
    
    #[test]
    fn test_runner_captures_failures() {
        let mut runner = LuxTestRunner::new(super::super::TestSuiteConfig::default());
        let result = runner.run_test("failing_test", || Err("Test failed".to_string()));
        
        assert!(!result.passed);
        assert!(result.message.is_some());
    }
    
    #[test]
    fn test_assertions() {
        assertions::assert_eq!(1, 1, "Numbers should be equal").unwrap();
        assertions::assert_true!(true, "Condition should be true").unwrap();
        assertions::assert_some!(Some(42), "Should have value").unwrap();
        assertions::assert_none!(None::<()>, "Should be none").unwrap();
    }
}
