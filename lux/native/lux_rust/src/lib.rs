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

use serde::{Serialize, Deserialize};
use serde::{Serialize, Deserialize};
use std::ffi::CString;

#[derive(Serialize, Deserialize)]
pub struct MyStruct {
    pub field1: String,
    pub field2: i32,
}

impl MyStruct {
    pub fn new(field1: String, field2: i32) -> Self {
        MyStruct { field1, field2 }
    }
}

pub fn encode_primitive<T: Serialize>(value: T) -> Result<String, serde_json::Error> {
    let serialized = serde_json::to_string(&value)?;
    Ok(serialized)
}

pub fn decode_primitive<T: Deserialize<'static>>(input: &str) -> Result<T, serde_json::Error> {
    let deserialized: T = serde_json::from_str(input)?;
    Ok(deserialized)
}
}