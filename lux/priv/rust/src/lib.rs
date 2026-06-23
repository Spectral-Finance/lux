//! Lux Rust Components
//!
//! This crate provides Rust-based components for the Lux framework.

/// Returns the Lux version string.
pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(version(), "0.1.0");
    }
}
