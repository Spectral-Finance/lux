//! Lux Rust Runtime
//!
//! This library serves as the runtime entry point for Rust code
//! executed through Lux's Rust/Cargo integration. Functions here
//! can be called from Elixir via the Lux.Rust module.

/// Returns the version of the rust runtime
pub fn version() -> &'static str {
    "0.1.0"
}

/// Evaluates a Rust expression in the context of this library.
pub fn eval(expression: &str) -> String {
    format!("eval not yet implemented: {}", expression)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(version(), "0.1.0");
    }
}
