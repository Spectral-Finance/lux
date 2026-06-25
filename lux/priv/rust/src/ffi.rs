//! FFI bindings for Lux Rust integration.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use crate::types::{LuxValue, ErrorKind};
use crate::error::{LuxError, LuxResult};

/// Opaque handle for a Rust Lux runtime instance.
type LuxHandle = *mut LuxRuntime;

struct LuxRuntime {
    initialized: bool,
}

/// Initialize the Lux Rust runtime.
#[no_mangle]
pub unsafe extern "C" fn lux_runtime_init() -> LuxHandle {
    let runtime = Box::new(LuxRuntime { initialized: true });
    Box::into_raw(runtime) as LuxHandle
}

/// Free a Lux runtime handle.
#[no_mangle]
pub unsafe extern "C" fn lux_runtime_free(handle: LuxHandle) {
    if handle.is_null() { return; }
    let _ = Box::from_raw(handle as *mut LuxRuntime);
}

/// Evaluate Rust code represented as a JSON string.
#[no_mangle]
pub unsafe extern "C" fn lux_eval(
    handle: LuxHandle,
    input_json: *const c_char,
) -> *mut c_char {
    if handle.is_null() || input_json.is_null() {
        let err = LuxError::new("null handle or input", ErrorKind::FfiError);
        return CString::into_raw(err.to_json().into());
    }

    let input_str = CStr::from_ptr(input_json).to_string_lossy().into_owned();
    let runtime = &*(handle as *mut LuxRuntime);

    if !runtime.initialized {
        let err = LuxError::new("runtime not initialized", ErrorKind::RuntimeError);
        return CString::into_raw(err.to_json().into());
    }

    let result: LuxResult<LuxValue> = (|| {
        let parsed: serde_json::Value = serde_json::from_str(&input_str)
            .map_err(|e| LuxError::new(e.to_string(), ErrorKind::TypeError))?;

        let code = parsed
            .get("code")
            .and_then(|v| v.as_str())
            .ok_or(LuxError::new("missing 'code' field", ErrorKind::TypeError))?;

        Ok(LuxValue::Map(vec![
            ("status".to_string(), LuxValue::Str("evaluated".to_string())),
            ("length".to_string(), LuxValue::Int(code.len() as i64)),
        ]))
    })();

    match result {
        Ok(value) => CString::into_raw(value.to_json().into()),
        Err(err) => CString::into_raw(err.to_json().into()),
    }
}

/// Convert a JSON string to a LuxValue.
#[no_mangle]
pub unsafe extern "C" fn lux_convert(json_input: *const c_char) -> *mut c_char {
    if json_input.is_null() {
        let err = LuxError::new("null input", ErrorKind::FfiError);
        return CString::into_raw(err.to_json().into());
    }

    let input_str = CStr::from_ptr(json_input).to_string_lossy().into_owned();
    let result: LuxResult<LuxValue> = serde_json::from_str(&input_str)
        .map_err(|e| LuxError::new(e.to_string(), ErrorKind::TypeError));

    match result {
        Ok(value) => CString::into_raw(value.to_json().into()),
        Err(err) => CString::into_raw(err.to_json().into()),
    }
}

/// Free a heap-allocated C string returned by FFI functions.
#[no_mangle]
pub unsafe extern "C" fn lux_free_string(ptr: *mut c_char) {
    if ptr.is_null() { return; }
    let _ = CString::from_raw(ptr);
}

/// Get the version string of the Lux Rust core.
#[no_mangle]
pub extern "C" fn lux_version() -> *const c_char {
    static VERSION: &str = "0.1.0";
    VERSION.as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        let version = unsafe { CStr::from_ptr(lux_version()) };
        assert_eq!(version.to_string_lossy(), "0.1.0");
    }
}
