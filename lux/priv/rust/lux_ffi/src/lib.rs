use serde::Serialize;
use serde_json::{json, Value};
use std::slice;

#[repr(C)]
pub struct LuxFfiBuffer {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}

#[derive(Debug, Serialize)]
struct LuxFfiError {
    code: &'static str,
    message: String,
}

impl LuxFfiError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

#[no_mangle]
pub extern "C" fn lux_ffi_execute_json(ptr: *const u8, len: usize) -> LuxFfiBuffer {
    let response = match read_input(ptr, len).and_then(execute_payload) {
        Ok(value) => json!({"ok": true, "value": value}),
        Err(error) => json!({"ok": false, "error": error}),
    };

    response_buffer(response)
}

#[no_mangle]
pub extern "C" fn lux_ffi_free_buffer(buffer: LuxFfiBuffer) {
    if buffer.ptr.is_null() || buffer.cap == 0 {
        return;
    }

    unsafe {
        let _ = Vec::from_raw_parts(buffer.ptr, buffer.len, buffer.cap);
    }
}

fn read_input(ptr: *const u8, len: usize) -> Result<Value, LuxFfiError> {
    if ptr.is_null() {
        return Err(LuxFfiError::new("invalid_input", "input pointer is null"));
    }

    let bytes = unsafe { slice::from_raw_parts(ptr, len) };

    serde_json::from_slice(bytes)
        .map_err(|error| LuxFfiError::new("invalid_json", error.to_string()))
}

fn execute_payload(payload: Value) -> Result<Value, LuxFfiError> {
    let operation = payload
        .get("operation")
        .and_then(Value::as_str)
        .ok_or_else(|| LuxFfiError::new("invalid_request", "missing operation"))?;

    let input = payload.get("input").cloned().unwrap_or(Value::Null);

    execute_operation(operation, input)
}

fn execute_operation(operation: &str, input: Value) -> Result<Value, LuxFfiError> {
    match operation {
        "echo" => Ok(input),
        "type_of" => Ok(json!({"type": type_of(&input)})),
        "sum_i64" => sum_i64(input),
        "is_truthy" => Ok(json!({"truthy": is_truthy(&input)})),
        _ => Err(LuxFfiError::new(
            "unknown_operation",
            format!("unsupported operation: {operation}"),
        )),
    }
}

fn sum_i64(input: Value) -> Result<Value, LuxFfiError> {
    let values = input
        .as_array()
        .ok_or_else(|| LuxFfiError::new("type_error", "sum_i64 expects an array"))?;

    let mut total: i64 = 0;

    for value in values {
        let number = value.as_i64().ok_or_else(|| {
            LuxFfiError::new(
                "type_error",
                format!("expected integer, got {}", type_of(value)),
            )
        })?;

        total = total
            .checked_add(number)
            .ok_or_else(|| LuxFfiError::new("overflow", "sum_i64 overflowed i64"))?;
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

fn response_buffer(value: Value) -> LuxFfiBuffer {
    let bytes = serde_json::to_vec(&value).unwrap_or_else(|error| {
        format!(
            r#"{{"ok":false,"error":{{"code":"encode_error","message":"{}"}}}}"#,
            error
        )
        .into_bytes()
    });

    into_buffer(bytes)
}

fn into_buffer(mut bytes: Vec<u8>) -> LuxFfiBuffer {
    let buffer = LuxFfiBuffer {
        ptr: bytes.as_mut_ptr(),
        len: bytes.len(),
        cap: bytes.capacity(),
    };

    std::mem::forget(bytes);
    buffer
}

#[cfg(test)]
mod tests {
    use super::*;

    fn call(payload: Value) -> Value {
        let bytes = serde_json::to_vec(&payload).unwrap();
        let buffer = lux_ffi_execute_json(bytes.as_ptr(), bytes.len());
        assert!(!buffer.ptr.is_null());

        let response = unsafe { slice::from_raw_parts(buffer.ptr, buffer.len) };
        let value = serde_json::from_slice(response).unwrap();
        lux_ffi_free_buffer(buffer);
        value
    }

    #[test]
    fn returns_type_information() {
        assert_eq!(
            call(json!({"operation": "type_of", "input": "lux"})),
            json!({"ok": true, "value": {"type": "string"}})
        );
    }

    #[test]
    fn sums_i64_values() {
        assert_eq!(
            call(json!({"operation": "sum_i64", "input": [4, 5, 6]})),
            json!({"ok": true, "value": {"sum": 15}})
        );
    }

    #[test]
    fn reports_typed_errors() {
        assert_eq!(
            call(json!({"operation": "sum_i64", "input": [1, "2"]})),
            json!({"ok": false, "error": {"code": "type_error", "message": "expected integer, got string"}})
        );
    }

    #[test]
    fn reports_null_pointer_input() {
        let buffer = lux_ffi_execute_json(std::ptr::null(), 0);
        let response = unsafe { slice::from_raw_parts(buffer.ptr, buffer.len) };
        let value: Value = serde_json::from_slice(response).unwrap();
        lux_ffi_free_buffer(buffer);

        assert_eq!(
            value,
            json!({"ok": false, "error": {"code": "invalid_input", "message": "input pointer is null"}})
        );
    }
}
