//! Prism implementations for Lux framework
//!
//! Prisms are pure functional components for specific data processing tasks.
//! This module provides Rust implementations of common prism types.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::Instant;

/// Prism configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrismConfig {
    /// Unique prism identifier
    pub id: String,
    /// Prism name
    pub name: String,
    /// Prism type
    pub prism_type: String,
    /// Configuration parameters
    #[serde(default)]
    pub config: serde_json::Value,
    /// Input schema description
    #[serde(default)]
    pub input_schema: Option<String>,
    /// Output schema description
    #[serde(default)]
    pub output_schema: Option<String>,
}

/// Prism execution result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrismExecutionResult {
    /// Prism ID
    pub prism_id: String,
    /// Execution status
    pub status: String,
    /// Output data
    pub output: Option<serde_json::Value>,
    /// Error message (if failed)
    pub error: Option<String>,
    /// Execution time in milliseconds
    pub execution_time_ms: f64,
}

/// Create a new prism configuration
pub fn create_prism(name: &str, prism_type: &str, config: Option<serde_json::Value>) -> PrismConfig {
    let id = format!("prism_{}_{}", name, uuid_short());
    PrismConfig {
        id,
        name: name.to_string(),
        prism_type: prism_type.to_string(),
        config: config.unwrap_or(serde_json::Value::Null),
        input_schema: None,
        output_schema: None,
    }
}

/// Handle prism input and return result
pub fn handle_prism(config: &PrismConfig, input: &serde_json::Value) -> PrismExecutionResult {
    let start = Instant::now();

    let result = match config.prism_type.as_str() {
        "data_filter" => execute_filter(config, input),
        "data_transform" => execute_transform(config, input),
        "data_aggregate" => execute_aggregate(config, input),
        "sentiment_analysis" => execute_sentiment(config, input),
        "eth_balance" => execute_eth_balance(config, input),
        _ => Err(format!("Unknown prism type: {}", config.prism_type)),
    };

    let elapsed = start.elapsed().as_secs_f64() * 1000.0;

    match result {
        Ok(output) => PrismExecutionResult {
            prism_id: config.id.clone(),
            status: "success".to_string(),
            output: Some(output),
            error: None,
            execution_time_ms: elapsed,
        },
        Err(error) => PrismExecutionResult {
            prism_id: config.id.clone(),
            status: "error".to_string(),
            output: None,
            error: Some(error),
            execution_time_ms: elapsed,
        },
    }
}

/// Filter prism - filters data based on criteria
fn execute_filter(
    config: &PrismConfig,
    input: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let items = input
        .as_array()
        .ok_or("Input must be an array for filter prism")?;

    let field = config
        .config
        .get("field")
        .and_then(|v| v.as_str())
        .ok_or("Missing 'field' in config")?;

    let value = config
        .config
        .get("value")
        .ok_or("Missing 'value' in config")?;

    let filtered: Vec<&serde_json::Value> = items
        .iter()
        .filter(|item| item.get(field).map_or(false, |v| v == value))
        .collect();

    Ok(serde_json::Value::Array(filtered.iter().map(|v| (*v).clone()).collect()))
}

/// Transform prism - transforms data fields
fn execute_transform(
    config: &PrismConfig,
    input: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let mut result = input.clone();

    let mappings = config
        .config
        .get("mappings")
        .and_then(|v| v.as_object())
        .ok_or("Missing 'mappings' in config")?;

    if let Some(obj) = result.as_object_mut() {
        for (key, new_key) in mappings {
            if let Some(value) = obj.remove(key) {
                obj.insert(new_key.as_str().unwrap_or(key).to_string(), value);
            }
        }
    }

    Ok(result)
}

/// Aggregate prism - aggregates numerical data
fn execute_aggregate(
    config: &PrismConfig,
    input: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let items = input
        .as_array()
        .ok_or("Input must be an array for aggregate prism")?;

    let field = config
        .config
        .get("field")
        .and_then(|v| v.as_str())
        .ok_or("Missing 'field' in config")?;

    let operation = config
        .config
        .get("operation")
        .and_then(|v| v.as_str())
        .unwrap_or("sum");

    let values: Vec<f64> = items
        .iter()
        .filter_map(|item| item.get(field).and_then(|v| v.as_f64()))
        .collect();

    if values.is_empty() {
        return Ok(serde_json::json!({
            "count": 0,
            "result": 0
        }));
    }

    let result = match operation {
        "sum" => values.iter().sum(),
        "avg" | "average" => values.iter().sum::<f64>() / values.len() as f64,
        "min" => values.iter().cloned().fold(f64::INFINITY, f64::min),
        "max" => values.iter().cloned().fold(f64::NEG_INFINITY, f64::max),
        "count" => values.len() as f64,
        _ => return Err(format!("Unknown operation: {}", operation)),
    };

    Ok(serde_json::json!({
        "operation": operation,
        "field": field,
        "count": values.len(),
        "result": result
    }))
}

/// Sentiment analysis prism - simple keyword-based sentiment
fn execute_sentiment(
    _config: &PrismConfig,
    input: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let text = input
        .as_str()
        .or_else(|| input.get("text").and_then(|v| v.as_str()))
        .ok_or("Input must be a string or contain 'text' field")?;

    let positive_words = ["good", "great", "excellent", "positive", "bullish", "up", "gain", "profit"];
    let negative_words = ["bad", "terrible", "poor", "negative", "bearish", "down", "loss", "crash"];

    let text_lower = text.to_lowercase();
    let mut score: f64 = 0.0;

    for word in &positive_words {
        if text_lower.contains(word) {
            score += 1.0;
        }
    }

    for word in &negative_words {
        if text_lower.contains(word) {
            score -= 1.0;
        }
    }

    let sentiment = if score > 0.0 {
        "positive"
    } else if score < 0.0 {
        "negative"
    } else {
        "neutral"
    };

    Ok(serde_json::json!({
        "sentiment": sentiment,
        "score": score,
        "text_length": text.len()
    }))
}

/// ETH balance prism - formats balance values
fn execute_eth_balance(
    _config: &PrismConfig,
    input: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let balance_wei = input
        .get("balance_wei")
        .or_else(|| input.as_str().map(|_| input))
        .and_then(|v| v.as_str())
        .ok_or("Missing 'balance_wei' field")?;

    let wei: u128 = balance_wei
        .parse()
        .map_err(|_| format!("Invalid balance value: {}", balance_wei))?;

    let ether = wei as f64 / 1e18;
    let gwei = wei as f64 / 1e9;

    Ok(serde_json::json!({
        "balance_wei": balance_wei,
        "balance_ether": format!("{:.18}", ether),
        "balance_gwei": format!("{:.9}", gwei),
        "balance_ether_rounded": format!("{:.6}", ether)
    }))
}

/// Generate a short UUID-like string
fn uuid_short() -> String {
    // Simplified - in production would use a proper UUID crate
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    format!("{:x}", timestamp & 0xFFFFFFFF)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_prism() {
        let prism = create_prism("test", "data_filter", None);
        assert_eq!(prism.name, "test");
        assert_eq!(prism.prism_type, "data_filter");
        assert!(prism.id.starts_with("prism_test_"));
    }

    #[test]
    fn test_filter_prism() {
        let prism = create_prism("filter", "data_filter", Some(serde_json::json!({
            "field": "chain_id",
            "value": 1
        })));

        let input = serde_json::json!([
            {"chain_id": 1, "name": "eth"},
            {"chain_id": 137, "name": "polygon"},
            {"chain_id": 1, "name": "eth2"}
        ]);

        let result = handle_prism(&prism, &input);
        assert_eq!(result.status, "success");
        let output = result.output.unwrap();
        assert_eq!(output.as_array().unwrap().len(), 2);
    }

    #[test]
    fn test_transform_prism() {
        let prism = create_prism("transform", "data_transform", Some(serde_json::json!({
            "mappings": {
                "old_field": "new_field"
            }
        })));

        let input = serde_json::json!({
            "old_field": "value",
            "other": "data"
        });

        let result = handle_prism(&prism, &input);
        assert_eq!(result.status, "success");
        let output = result.output.unwrap();
        assert!(output.get("new_field").is_some());
        assert!(output.get("old_field").is_none());
    }

    #[test]
    fn test_aggregate_prism() {
        let prism = create_prism("agg", "data_aggregate", Some(serde_json::json!({
            "field": "value",
            "operation": "sum"
        })));

        let input = serde_json::json!([
            {"value": 10},
            {"value": 20},
            {"value": 30}
        ]);

        let result = handle_prism(&prism, &input);
        assert_eq!(result.status, "success");
        let output = result.output.unwrap();
        assert_eq!(output["result"], 60.0);
        assert_eq!(output["count"], 3);
    }

    #[test]
    fn test_aggregate_average() {
        let prism = create_prism("agg", "data_aggregate", Some(serde_json::json!({
            "field": "value",
            "operation": "average"
        })));

        let input = serde_json::json!([
            {"value": 10},
            {"value": 20},
            {"value": 30}
        ]);

        let result = handle_prism(&prism, &input);
        assert_eq!(result.output.unwrap()["result"], 20.0);
    }

    #[test]
    fn test_sentiment_prism() {
        let prism = create_prism("sentiment", "sentiment_analysis", None);

        let positive = serde_json::json!("The market is looking great and bullish today!");
        let result = handle_prism(&prism, &positive);
        assert_eq!(result.output.unwrap()["sentiment"], "positive");

        let negative = serde_json::json!("There was a crash and massive losses today");
        let result = handle_prism(&prism, &negative);
        assert_eq!(result.output.unwrap()["sentiment"], "negative");
    }

    #[test]
    fn test_eth_balance_prism() {
        let prism = create_prism("balance", "eth_balance", None);

        let input = serde_json::json!({
            "balance_wei": "1000000000000000000"
        });

        let result = handle_prism(&prism, &input);
        assert_eq!(result.status, "success");
        let output = result.output.unwrap();
        assert!(output["balance_ether"].as_str().unwrap().starts_with("1.0"));
    }

    #[test]
    fn test_unknown_prism_type() {
        let prism = create_prism("unknown", "unknown_type", None);
        let result = handle_prism(&prism, &serde_json::json!(null));
        assert_eq!(result.status, "error");
        assert!(result.error.is_some());
    }
}
