use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct TestResult {
    pub name: String,
    pub passed: bool,
    pub duration_ms: u64,
    pub error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TestSuite {
    pub name: String,
    pub tests: Vec<TestResult>,
    pub total_duration_ms: u64,
}

pub fn create_test_suite(name: &str) -> TestSuite {
    TestSuite {
        name: name.to_string(),
        tests: Vec::new(),
        total_duration_ms: 0,
    }
}

pub fn add_result(suite: &mut TestSuite, result: TestResult) {
    suite.total_duration_ms += result.duration_ms;
    suite.tests.push(result);
}

pub fn summary(suite: &TestSuite) -> String {
    let total = suite.tests.len();
    let passed = suite.tests.iter().filter(|t| t.passed).count();
    let failed = total - passed;
    format!(
        "{}: {} passed, {} failed, {} total ({}.{:03}s)",
        suite.name,
        passed,
        failed,
        total,
        suite.total_duration_ms / 1000,
        suite.total_duration_ms % 1000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_empty_suite() {
        let suite = create_test_suite("unit");
        assert_eq!(suite.name, "unit");
        assert!(suite.tests.is_empty());
        assert_eq!(suite.total_duration_ms, 0);
    }

    #[test]
    fn test_add_results() {
        let mut suite = create_test_suite("integration");
        add_result(
            &mut suite,
            TestResult {
                name: "test_foo".into(),
                passed: true,
                duration_ms: 10,
                error: None,
            },
        );
        add_result(
            &mut suite,
            TestResult {
                name: "test_bar".into(),
                passed: false,
                duration_ms: 5,
                error: Some("assertion failed".into()),
            },
        );
        assert_eq!(suite.tests.len(), 2);
        assert_eq!(suite.total_duration_ms, 15);
    }

    #[test]
    fn test_summary_format() {
        let mut suite = create_test_suite("core");
        add_result(
            &mut suite,
            TestResult {
                name: "t1".into(),
                passed: true,
                duration_ms: 100,
                error: None,
            },
        );
        add_result(
            &mut suite,
            TestResult {
                name: "t2".into(),
                passed: false,
                duration_ms: 200,
                error: Some("fail".into()),
            },
        );
        let s = summary(&suite);
        assert!(s.contains("core"));
        assert!(s.contains("1 passed"));
        assert!(s.contains("1 failed"));
        assert!(s.contains("2 total"));
    }

    #[test]
    fn test_serialization_roundtrip() {
        let mut suite = create_test_suite("serialize");
        add_result(
            &mut suite,
            TestResult {
                name: "add".into(),
                passed: true,
                duration_ms: 7,
                error: None,
            },
        );
        let json = serde_json::to_string(&suite).unwrap();
        let deserialized: TestSuite = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.name, "serialize");
        assert_eq!(deserialized.tests.len(), 1);
        assert_eq!(deserialized.tests[0].name, "add");
    }

    #[test]
    fn test_all_passed_count() {
        let mut suite = create_test_suite("all_pass");
        for i in 0..5 {
            add_result(
                &mut suite,
                TestResult {
                    name: format!("test_{}", i),
                    passed: true,
                    duration_ms: 1,
                    error: None,
                },
            );
        }
        let passed = suite.tests.iter().filter(|t| t.passed).count();
        assert_eq!(passed, 5);
    }
}
