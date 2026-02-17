use std::os::raw::c_char;
use std::ffi::CStr;

#[no_mangle]
pub extern "C" fn lux_rust_nif_init() -> *mut c_char {
    let response = "NIF initialized successfully";
    unsafe { CStr::from_ptr(response.as_ptr()).as_ptr() }
}

use std::os::raw::c_int;

#[no_mangle]
pub extern "C" fn lux_rust_nif_encode(value: c_int) -> *mut c_char {
    let response = format!("Encoded value: {}", value);
    unsafe { CStr::from_ptr(response.as_ptr()).as_ptr() }
}