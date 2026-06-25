//! Lux Rust Core - high-performance native code for the Lux framework.
//!
//! This crate provides the Rust-side foundation for Lux language integration,
//! including FFI bindings, type conversion, and error handling.

pub mod types;
pub mod error;
pub mod ffi;
pub mod conversion;

/// Initialize the Rust core runtime.
#[no_mangle]
pub extern "C" fn lux_rust_init() -> *mut std::ffi::c_char {
    let msg = "Lux Rust core initialized successfully";
    let boxed = msg.to_string();
    let raw = boxed.into_boxed_str();
    Box::into_raw(raw) as *mut std::ffi::c_char
}

/// Shutdown the Rust core runtime and free resources.
///
/// # Safety
#[no_mangle]
pub unsafe extern "C" fn lux_rust_shutdown() {
    // Cleanup any global state here
}
