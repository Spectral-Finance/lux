//! Core Rust bridge for the Lux Agent Framework.
//! Provides memory-safe type conversions, FFI error propagation, and invocation dispatch.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use thiserror::Error;

#[derive(Error, Debug, Serialize, Deserialize)]
pub enum LuxRustError {
    #[error("Invalid JSON input: {0}")]
    JsonError(String),
    #[error("Null pointer provided to FFI function")]
    NullPointer,
    #[error("Function not found: {0}")]
    FunctionNotFound(String),
    #[error("Execution failed: {0}")]
    ExecutionError(String),
}

#[derive(Serialize, Deserialize, Debug)]
pub struct FfiResponse {
    pub success: bool,
    pub data: Option<Value>,
    pub error: Option<String>,
}

impl FfiResponse {
    pub fn ok(data: Value) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn err(err: LuxRustError) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(err.to_string()),
        }
    }
}

/// Invokes a named Rust operation with a JSON-encoded input payload.
/// Guarantees panic-safety and memory isolation across FFI boundary.
#[no_mangle]
pub extern "C" fn lux_rust_invoke(
    func_name: *const c_char,
    payload_json: *const c_char,
) -> *mut c_char {
    let result = std::panic::catch_unwind(|| {
        if func_name.is_null() || payload_json.is_null() {
            return FfiResponse::err(LuxRustError::NullPointer);
        }

        let c_func = unsafe { CStr::from_ptr(func_name) };
        let c_payload = unsafe { CStr::from_ptr(payload_json) };

        let func_str = match c_func.to_str() {
            Ok(s) => s,
            Err(e) => return FfiResponse::err(LuxRustError::ExecutionError(e.to_string())),
        };

        let payload_str = match c_payload.to_str() {
            Ok(s) => s,
            Err(e) => return FfiResponse::err(LuxRustError::ExecutionError(e.to_string())),
        };

        let parsed_val: Value = match serde_json::from_str(payload_str) {
            Ok(v) => v,
            Err(e) => return FfiResponse::err(LuxRustError::JsonError(e.to_string())),
        };

        match func_str {
            "echo" => FfiResponse::ok(parsed_val),
            "ping" => FfiResponse::ok(serde_json::json!({"status": "pong", "runtime": "rust"})),
            other => FfiResponse::err(LuxRustError::FunctionNotFound(other.to_string())),
        }
    });

    let resp = match result {
        Ok(r) => r,
        Err(_) => FfiResponse::err(LuxRustError::ExecutionError("Fatal panic in Rust FFI invocation".into())),
    };

    let serialized = serde_json::to_string(&resp).unwrap_or_else(|_| {
        r#"{"success":false,"data":null,"error":"Serialization failure"}"#.to_string()
    });

    CString::new(serialized).unwrap().into_raw()
}

/// Frees a string previously allocated by `lux_rust_invoke`.
#[no_mangle]
pub extern "C" fn lux_rust_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
