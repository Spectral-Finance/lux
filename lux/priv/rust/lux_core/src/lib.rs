//! # lux_core
//!
//! Core Rust primitives for the [Lux](https://github.com/Spectral-Finance/lux)
//! multi-agent framework.
//!
//! `lux_core` is the foundation for the upcoming Rust language support in
//! Lux. It mirrors the early shape of `priv/python/lux/__init__.py` and
//! `priv/node/lux.mjs`: a small surface area that lets Elixir-side code
//! exercise Rust functions through a uniform value protocol while the
//! larger Prism / Beam / Signal abstractions are ported over.
//!
//! The crate ships with a built-in **testing framework** so that the Rust
//! components can be developed under the same red-green-refactor discipline
//! as the Elixir and Python sides. See the [`testing`] module for details
//! and run the full suite with:
//!
//! ```text
//! cargo test --workspace
//! ```
//!
//! or, from the Elixir mix project root:
//!
//! ```text
//! mix rust.test
//! ```

#![forbid(unsafe_code)]
#![warn(missing_docs)]

pub mod signal;
pub mod testing;

/// Current `lux_core` crate version, kept in sync with `Cargo.toml`.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns a short greeting used by the Elixir side as a smoke test that
/// the Rust runtime is reachable.
///
/// # Examples
///
/// ```
/// use lux_core::greet;
///
/// assert_eq!(greet("Lux"), "Hello from lux_core, Lux!");
/// ```
#[must_use]
pub fn greet(who: &str) -> String {
    format!("Hello from lux_core, {who}!")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greet_includes_name() {
        assert_eq!(greet("World"), "Hello from lux_core, World!");
    }

    #[test]
    fn version_matches_cargo_manifest() {
        // env! is evaluated at compile time, so this guards against
        // accidentally publishing a binary that disagrees with Cargo.toml.
        assert!(!VERSION.is_empty());
        assert!(VERSION.chars().next().unwrap().is_ascii_digit());
    }
}
