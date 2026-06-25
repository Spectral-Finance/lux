//! Integration tests for Lux Rust core.

use lux_rust::types::LuxValue;
use lux_rust::conversion::{json_to_lux_value, lux_value_to_json, lux_add, lux_concat};
use lux_rust::error::{LuxError, ErrorKind};

#[test]
fn test_full_conversion_pipeline() {
    let json = serde_json::json!({
        "name": "Alice",
        "scores": [95, 87, 92],
        "active": true,
        "metadata": null
    });
    let value = json_to_lux_value(&json).unwrap();
    let back = lux_value_to_json(&value);
    assert_eq!(back["name"], "Alice");
    assert_eq!(back["scores"][0], 95);
    assert_eq!(back["active"], true);
}

#[test]
fn test_arithmetic_operations() {
    let a = LuxValue::Int(100);
    let b = LuxValue::Int(200);
    let result = lux_add(&a, &b).unwrap();
    assert_eq!(result, LuxValue::Int(300));
}

#[test]
fn test_string_operations() {
    let a = LuxValue::Str("Hello".to_string());
    let b = LuxValue::Str(" World".to_string());
    let result = lux_concat(&a, &b).unwrap();
    assert_eq!(result, LuxValue::Str("Hello World".to_string()));
}

#[test]
fn test_error_propagation() {
    let err = LuxError::new("test error", ErrorKind::TypeError)
        .with_source("root cause")
        .with_context("test context");
    let json = err.to_json();
    let restored = LuxError::from_json(&json);
    assert_eq!(restored.message, "test error");
    assert_eq!(restored.kind, ErrorKind::TypeError);
}

#[test]
fn test_nested_structures() {
    let nested = LuxValue::Map(vec![
        ("outer".to_string(), LuxValue::Map(vec![
            ("inner".to_string(), LuxValue::List(vec![
                LuxValue::Int(1), LuxValue::Int(2), LuxValue::Int(3),
            ])),
        ])),
    ]);
    let json = lux_value_to_json(&nested);
    let value = json_to_lux_value(&json).unwrap();
    assert_eq!(value, nested);
}
