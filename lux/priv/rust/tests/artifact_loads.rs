//! End-to-end *artifact* test.
//!
//! The unit tests in `src/` exercise the pure `*_impl` logic. This test goes a
//! step further and proves the **compiled `cdylib` artifact** is a real, loadable
//! shared object that exports the Rustler NIF entry point (`nif_init`) — i.e.
//! the exact symbol the BEAM resolves when `Lux.Rust.load_nif/0` loads the NIF.
//!
//! It does this by:
//!   1. Building the `cdylib` (`cargo build --lib`; `cargo test` does not build
//!      `cdylib` crate-types on its own).
//!   2. Dynamically loading the resulting `liblux_rust.so` with `dlopen`.
//!   3. Resolving the `nif_init` symbol with `dlsym`.
//!
//! The full BEAM-side call path (load + invoke every NIF) is covered by
//! `test/integration/rust_test.exs`, run via `mix test --include integration`.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::path::PathBuf;
use std::process::Command;

extern "C" {
    fn dlopen(filename: *const c_char, flag: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dlerror() -> *mut c_char;
}

// `RTLD_NOW` from <dlfcn.h>: resolve all undefined symbols on load.
const RTLD_NOW: c_int = 2;

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

/// Locate the built `cdylib`. The crate may be built either standalone (target
/// dir under the crate) or as part of the repo-root workspace (target dir at the
/// workspace root), so probe every candidate and return the first that exists.
fn cdylib_path() -> PathBuf {
    let manifest = manifest_dir();
    let mut candidates = vec![
        manifest.join("target/debug/liblux_rust.so"),
        manifest.join("target/release/liblux_rust.so"),
        // Workspace-root target dir (this crate is a member of ../../Cargo.toml).
        manifest.join("../../../target/debug/liblux_rust.so"),
        manifest.join("../../../target/release/liblux_rust.so"),
    ];
    // Honour an explicit CARGO_TARGET_DIR if the caller set one.
    if let Ok(dir) = std::env::var("CARGO_TARGET_DIR") {
        let base = PathBuf::from(dir);
        candidates.push(base.join("debug/liblux_rust.so"));
        candidates.push(base.join("release/liblux_rust.so"));
    }
    candidates
        .into_iter()
        .find(|p| p.exists())
        .unwrap_or_else(|| manifest.join("target/debug/liblux_rust.so"))
}

#[test]
fn compiled_cdylib_loads_and_exports_nif_init() {
    // 1. Build the cdylib artifact. `cargo test` builds the rlib/test harness but
    //    not the `cdylib` crate-type, so build it explicitly. Cargo releases the
    //    target-dir lock before running test binaries, so this nested build does
    //    not deadlock.
    let status = Command::new("cargo")
        .arg("build")
        .arg("--lib")
        .current_dir(manifest_dir())
        .status()
        .expect("failed to spawn `cargo build --lib`");
    assert!(status.success(), "`cargo build --lib` failed with {status}");

    // 2. The artifact must exist and be non-empty.
    let path = cdylib_path();
    assert!(
        path.exists(),
        "cdylib artifact not found at {}",
        path.display()
    );
    let meta = std::fs::metadata(&path).expect("stat cdylib");
    assert!(meta.len() > 0, "cdylib artifact is empty: {}", path.display());

    // 3. Load it. A successful `dlopen` proves the file is a well-formed,
    //    relocation-complete shared object (all symbols resolved).
    let cpath = CString::new(path.to_str().expect("utf-8 path")).expect("nul-free path");
    let handle = unsafe { dlopen(cpath.as_ptr(), RTLD_NOW) };
    assert!(
        !handle.is_null(),
        "dlopen({}) failed: {}",
        path.display(),
        unsafe { CStr::from_ptr(dlerror()) }.to_string_lossy()
    );

    // 4. The BEAM resolves `nif_init` when loading a Rustler NIF; it must exist.
    let sym = CString::new("nif_init").expect("nul-free symbol");
    let entry = unsafe { dlsym(handle, sym.as_ptr()) };
    assert!(
        !entry.is_null(),
        "cdylib does not export the `nif_init` entry point ({}): {}",
        path.display(),
        unsafe { CStr::from_ptr(dlerror()) }.to_string_lossy()
    );
}