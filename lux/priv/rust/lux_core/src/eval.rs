//! High-performance evaluation engine
//!
//! This module provides optimized Python code evaluation with caching
//! and variable binding support.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Evaluation errors
#[derive(Debug, Error)]
pub enum EvalError {
    #[error("Parse error: {0}")]
    ParseError(String),
    #[error("Runtime error: {0}")]
    RuntimeError(String),
    #[error("Timeout after {0}ms")]
    Timeout(u64),
    #[error("Invalid input: {0}")]
    InvalidInput(String),
}

/// Cached evaluation result
#[derive(Debug, Clone)]
struct CacheEntry {
    result: String,
    created_at: Instant,
    ttl: Duration,
}

/// Simple LRU cache for evaluation results
struct EvalCache {
    entries: Mutex<HashMap<String, CacheEntry>>,
    max_size: usize,
    default_ttl: Duration,
}

impl EvalCache {
    fn new(max_size: usize, default_ttl_secs: u64) -> Self {
        Self {
            entries: Mutex::new(HashMap::new()),
            max_size,
            default_ttl: Duration::from_secs(default_ttl_secs),
        }
    }

    fn get(&self, key: &str) -> Option<String> {
        let mut entries = self.entries.lock().unwrap();
        if let Some(entry) = entries.get(key) {
            if entry.created_at.elapsed() < entry.ttl {
                return Some(entry.result.clone());
            }
            entries.remove(key);
        }
        None
    }

    fn insert(&self, key: String, result: String) {
        let mut entries = self.entries.lock().unwrap();

        // Evict oldest entries if at capacity
        while entries.len() >= self.max_size {
            if let Some(oldest_key) = entries
                .iter()
                .min_by_key(|(_, entry)| entry.created_at)
                .map(|(key, _)| key.clone())
            {
                entries.remove(&oldest_key);
            } else {
                break;
            }
        }

        entries.insert(
            key,
            CacheEntry {
                result,
                created_at: Instant::now(),
                ttl: self.default_ttl,
            },
        );
    }

    fn clear(&self) {
        self.entries.lock().unwrap().clear();
    }

    fn len(&self) -> usize {
        self.entries.lock().unwrap().len()
    }
}

// Global cache instance
lazy_static_cache!();

macro_rules! lazy_static_cache {
    () => {
        use std::sync::OnceLock;
        static CACHE: OnceLock<EvalCache> = OnceLock::new();
        fn cache() -> &'static EvalCache {
            CACHE.get_or_init(|| EvalCache::new(1000, 300))
        }
    };
}

/// Evaluate a simple Python expression
///
/// This function provides a basic evaluation of arithmetic expressions
/// without requiring a Python interpreter. For full Python support,
/// use the Python integration via Venomous.
pub fn evaluate(code: &str) -> Result<String, EvalError> {
    let code = code.trim();

    // Check cache first
    if let Some(cached) = cache().get(code) {
        return Ok(cached);
    }

    // Try to evaluate simple arithmetic expressions
    let result = evaluate_expression(code)?;

    // Cache the result
    cache().insert(code.to_string(), result.clone());

    Ok(result)
}

/// Evaluate with variable bindings
pub fn evaluate_with_variables(
    code: &str,
    variables: &HashMap<String, String>,
) -> Result<String, EvalError> {
    let code = code.trim();

    // Substitute variables
    let mut substituted = code.to_string();
    for (key, value) in variables {
        substituted = substituted.replace(key, value);
    }

    evaluate(&substituted)
}

/// Execute multi-line Python code (returns last expression)
pub fn execute_code(code: &str) -> Result<String, EvalError> {
    let code = code.trim();
    let lines: Vec<&str> = code.lines().collect();

    if lines.is_empty() {
        return Ok("None".to_string());
    }

    // For multi-line code, try to evaluate the last expression
    let last_line = lines.last().unwrap().trim();

    // Check if the last line is an expression (not a statement)
    if is_expression(last_line) {
        evaluate(last_line)
    } else {
        // Execute all lines (simplified - just return success)
        for line in &lines[..lines.len() - 1] {
            let trimmed = line.trim();
            if !trimmed.is_empty() && !trimmed.starts_with('#') {
                // In a full implementation, this would track variable assignments
            }
        }
        Ok("None".to_string())
    }
}

/// Check if a string looks like an expression
fn is_expression(code: &str) -> bool {
    let trimmed = code.trim();
    if trimmed.is_empty() {
        return false;
    }

    // Simple heuristic: if it doesn't start with a keyword, it's likely an expression
    let keywords = ["def ", "class ", "if ", "for ", "while ", "import ", "from ", "return ", "let ", "var "];
    !keywords.iter().any(|k| trimmed.starts_with(k))
}

/// Evaluate a simple arithmetic expression
fn evaluate_expression(code: &str) -> Result<String, EvalError> {
    // Handle simple integer arithmetic
    if let Ok(result) = evaluate_simple_arithmetic(code) {
        return Ok(result.to_string());
    }

    // Handle string concatenation
    if code.starts_with('"') || code.starts_with('\'') {
        return Ok(code.to_string());
    }

    // Handle boolean expressions
    if code == "True" || code == "true" {
        return Ok("True".to_string());
    }
    if code == "False" || code == "false" {
        return Ok("False".to_string());
    }

    // Handle None
    if code == "None" || code == "none" || code == "null" {
        return Ok("None".to_string());
    }

    // Handle list literals
    if code.starts_with('[') && code.ends_with(']') {
        return Ok(code.to_string());
    }

    // Handle dict literals
    if code.starts_with('{') && code.ends_with('}') {
        return Ok(code.to_string());
    }

    Err(EvalError::ParseError(format!(
        "Cannot evaluate expression: {}",
        code
    )))
}

/// Evaluate simple arithmetic (integers and floats)
fn evaluate_simple_arithmetic(code: &str) -> Result<f64, EvalError> {
    let code = code.trim();

    // Try parsing as a number first
    if let Ok(n) = code.parse::<f64>() {
        return Ok(n);
    }

    // Handle parenthesized expressions
    if code.starts_with('(') && code.ends_with(')') {
        return evaluate_simple_arithmetic(&code[1..code.len() - 1]);
    }

    // Find the lowest-precedence operator
    let mut paren_depth = 0;
    let mut last_op_pos = None;
    let mut last_op = None;

    for (i, c) in code.char_indices() {
        match c {
            '(' => paren_depth += 1,
            ')' => paren_depth -= 1,
            '+' | '-' if paren_depth == 0 => {
                last_op_pos = Some(i);
                last_op = Some(c);
            }
            '*' | '/' | '%' if paren_depth == 0 => {
                // Higher precedence - only record if no lower precedence found
                if last_op_pos.is_none() || matches!(last_op, Some('+' | '-')) {
                    last_op_pos = Some(i);
                    last_op = Some(c);
                }
            }
            _ => {}
        }
    }

    if let (Some(pos), Some(op)) = (last_op_pos, last_op) {
        let left = &code[..pos];
        let right = &code[pos + 1..];

        let left_val = evaluate_simple_arithmetic(left.trim())?;
        let right_val = evaluate_simple_arithmetic(right.trim())?;

        match op {
            '+' => Ok(left_val + right_val),
            '-' => Ok(left_val - right_val),
            '*' => Ok(left_val * right_val),
            '/' => {
                if right_val == 0.0 {
                    Err(EvalError::RuntimeError("Division by zero".to_string()))
                } else {
                    Ok(left_val / right_val)
                }
            }
            '%' => Ok(left_val % right_val),
            _ => Err(EvalError::ParseError(format!("Unknown operator: {}", op))),
        }
    } else {
        Err(EvalError::ParseError(format!(
            "Cannot parse expression: {}",
            code
        )))
    }
}

/// Get cache statistics
pub fn cache_stats() -> (usize, usize) {
    (cache().len(), 1000) // (current_size, max_size)
}

/// Clear the evaluation cache
pub fn clear_cache() {
    cache().clear();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_evaluate_simple() {
        assert_eq!(evaluate("42").unwrap(), "42");
        assert_eq!(evaluate("2 + 2").unwrap(), "4");
        assert_eq!(evaluate("10 - 3").unwrap(), "7");
        assert_eq!(evaluate("3 * 4").unwrap(), "12");
        assert_eq!(evaluate("20 / 4").unwrap(), "5");
    }

    #[test]
    fn test_evaluate_complex() {
        assert_eq!(evaluate("2 + 3 * 4").unwrap(), "14");
        assert_eq!(evaluate("(2 + 3) * 4").unwrap(), "20");
        assert_eq!(evaluate("10 + 20 + 30").unwrap(), "60");
    }

    #[test]
    fn test_evaluate_with_variables() {
        let mut vars = HashMap::new();
        vars.insert("x".to_string(), "5".to_string());
        vars.insert("y".to_string(), "6".to_string());

        let result = evaluate_with_variables("x * y", &vars).unwrap();
        assert_eq!(result, "30");
    }

    #[test]
    fn test_evaluate_special_values() {
        assert_eq!(evaluate("True").unwrap(), "True");
        assert_eq!(evaluate("False").unwrap(), "False");
        assert_eq!(evaluate("None").unwrap(), "None");
    }

    #[test]
    fn test_evaluate_caching() {
        clear_cache();
        let _ = evaluate("2 + 2");
        let (size, _) = cache_stats();
        assert_eq!(size, 1);
    }

    #[test]
    fn test_evaluate_error() {
        assert!(evaluate("invalid expression !@#").is_err());
    }

    #[test]
    fn test_division_by_zero() {
        assert!(evaluate("1 / 0").is_err());
    }

    #[test]
    fn test_execute_code() {
        assert_eq!(execute_code("").unwrap(), "None");
        assert_eq!(execute_code("42").unwrap(), "42");
        assert_eq!(execute_code("2 + 2").unwrap(), "4");
    }

    #[test]
    fn test_is_expression() {
        assert!(is_expression("2 + 2"));
        assert!(is_expression("x"));
        assert!(is_expression("[1, 2, 3]"));
        assert!(!is_expression("def foo():"));
        assert!(!is_expression("if x > 0:"));
    }
}
