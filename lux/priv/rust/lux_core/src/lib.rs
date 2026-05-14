use serde::Serialize;
use serde_json::{json, Value};

#[derive(Debug, Serialize)]
pub struct LuxRustError {
    pub code: &'static str,
    pub message: String,
}

impl LuxRustError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

pub fn execute(operation: &str, input: Value) -> Result<Value, LuxRustError> {
    match operation {
        "echo" => Ok(input),
        "type_of" => Ok(json!({"type": type_of(&input)})),
        "sum_i64" => sum_i64(input),
        "is_truthy" => Ok(json!({"truthy": is_truthy(&input)})),
        _ => Err(LuxRustError::new(
            "unknown_operation",
            format!("unsupported Rust operation: {operation}"),
        )),
    }
}

fn sum_i64(input: Value) -> Result<Value, LuxRustError> {
    let values = input.as_array().ok_or_else(|| {
        LuxRustError::new("type_error", "sum_i64 expects a JSON array of integers")
    })?;

    let mut total: i64 = 0;

    for value in values {
        let number = value.as_i64().ok_or_else(|| {
            LuxRustError::new(
                "type_error",
                format!("expected integer, got {}", type_of(value)),
            )
        })?;

        total = total.checked_add(number).ok_or_else(|| {
            LuxRustError::new("overflow", "sum_i64 overflowed an i64 accumulator")
        })?;
    }

    Ok(json!({"sum": total}))
}

fn type_of(value: &Value) -> &'static str {
    match value {
        Value::Null => "null",
        Value::Bool(_) => "boolean",
        Value::Number(number) if number.is_i64() || number.is_u64() => "integer",
        Value::Number(_) => "float",
        Value::String(_) => "string",
        Value::Array(_) => "array",
        Value::Object(_) => "object",
    }
}

fn is_truthy(value: &Value) -> bool {
    match value {
        Value::Null => false,
        Value::Bool(value) => *value,
        Value::Number(number) => number.as_f64().is_some_and(|value| value != 0.0),
        Value::String(value) => !value.is_empty(),
        Value::Array(value) => !value.is_empty(),
        Value::Object(value) => !value.is_empty(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn echoes_json_values() {
        let input = json!({"name": "lux", "count": 2});
        assert_eq!(execute("echo", input.clone()).unwrap(), input);
    }

    #[test]
    fn returns_type_information() {
        assert_eq!(
            execute("type_of", json!("lux")).unwrap(),
            json!({"type": "string"})
        );
        assert_eq!(
            execute("type_of", json!(42)).unwrap(),
            json!({"type": "integer"})
        );
        assert_eq!(
            execute("type_of", json!(4.2)).unwrap(),
            json!({"type": "float"})
        );
    }

    #[test]
    fn sums_i64_values() {
        assert_eq!(
            execute("sum_i64", json!([1, 2, 3])).unwrap(),
            json!({"sum": 6})
        );
    }

    #[test]
    fn reports_type_errors() {
        let err = execute("sum_i64", json!(["1"])).unwrap_err();
        assert_eq!(err.code, "type_error");
    }
}
