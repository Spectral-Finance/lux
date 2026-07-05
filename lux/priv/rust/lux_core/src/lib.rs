use rustler::{Encoder, Env, Error, NifResult, Term};
use thiserror::Error;

rustler::atoms! {
    error,
}

#[derive(Error, Debug)]
pub enum LuxError {
    #[error("Type conversion error: {0}")]
    TypeConversion(String),
    #[error("Memory safety error: {0}")]
    MemorySafety(String),
}

impl rustler::Encoder for LuxError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let err_str = self.to_string();
        (error(), err_str).encode(env)
    }
}

impl From<LuxError> for Error {
    fn from(err: LuxError) -> Self {
        Error::Term(Box::new(err.to_string()))
    }
}

/// A basic example of type conversion and FFI bindings with memory safety.
/// Accepts two integers from Elixir, adds them securely, and returns the result.
#[rustler::nif]
fn add(a: i64, b: i64) -> NifResult<i64> {
    a.checked_add(b)
        .ok_or_else(|| Error::Term(Box::new("Integer overflow".to_string())))
}

/// Complex task example to demonstrate error handling framework with proper propagation.
#[rustler::nif]
fn compute_complex_task(data: String) -> Result<String, LuxError> {
    if data.is_empty() {
        return Err(LuxError::TypeConversion("Data cannot be empty".to_string()));
    }
    
    // Simulate some memory-safe operation
    let processed = format!("Processed: {}", data);
    
    Ok(processed)
}

rustler::init!("Elixir.Lux.RustCore", [add, compute_complex_task]);
