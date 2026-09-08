//! Shared Tokio runtime for async Prism handlers.
//!
//! Created once at NIF load. `block_on` is only called from DirtyCpu NIFs
//! so a waiting future cannot stall a normal BEAM scheduler.

use std::sync::OnceLock;
use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Result<Runtime, String>> = OnceLock::new();

pub fn runtime() -> Result<&'static Runtime, String> {
    match RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_time()
            .thread_name("lux-async")
            .build()
            .map_err(|e| format!("failed to start tokio runtime: {e}"))
    }) {
        Ok(rt) => Ok(rt),
        Err(e) => Err(e.clone()),
    }
}

pub fn available() -> bool {
    runtime().is_ok()
}

pub fn block_on<F, T>(fut: F) -> Result<T, String>
where
    F: std::future::Future<Output = T>,
{
    Ok(runtime()?.block_on(fut))
}
