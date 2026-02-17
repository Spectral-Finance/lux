use serde::{Serialize, Deserialize};
use std::ffi::CString;

#[derive(Serialize, Deserialize)]
pub struct MyStruct {
    field1: String,
    field2: String,
}

impl MyStruct {
    pub fn new(field1: &str, field2: &str) -> Self {
        MyStruct {
            field1: field1.to_string(),
            field2: field2.to_string(),
        }
    }

    pub fn to_rust_field1(&self) -> CString {
        CString::new(self.field1.clone()).unwrap()
    }

    pub fn from_rust_field1(rust_value: *const libc::c_char) -> Self {
        let field1 = unsafe { std::ffi::CStr::from_ptr(rust_value).to_str().unwrap() };
        MyStruct {
            field1: field1.to_string(),
            field2: self.field2.clone(),
        }
    }

    pub fn to_rust_field2(&self) -> CString {
        CString::new(self.field2.clone()).unwrap()
    }

    pub fn from_rust_field2(rust_value: *const libc::c_char) -> Self {
        let field2 = unsafe { std::ffi::CStr::from_ptr(rust_value).to_str().unwrap() };
        MyStruct {
            field1: self.field1.clone(),
            field2: field2.to_string(),
        }
    }
}