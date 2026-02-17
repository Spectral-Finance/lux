use std::os::raw::c_char;
use std::ffi::CStr;

extern "C" {
    fn lux_rust_function(input: *const c_char) -> *const c_char;
}

pub fn call_lux_rust_function(input: &str) -> String {
    unsafe {
        let input_c_str = CStr::from_bytes_with_nul_unchecked(input.as_bytes());
        let output_c_str = lux_rust_function(input_c_str.as_ptr());
        String::from_utf8_lossy(CStr::from_ptr(output_c_str).to_bytes()).into_owned()
    }
}

pub fn encode_primitive(value: i32) -> String {
    format!("{}", value)
}