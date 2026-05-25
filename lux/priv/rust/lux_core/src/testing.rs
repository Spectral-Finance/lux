//! Testing utilities for the Lux Rust components.
//!
//! This module is the heart of the **Lux Rust Testing Framework**. It
//! provides small, dependency-free helpers that let contributors write
//! deterministic, readable tests for Lux's Rust-side primitives — the
//! same way `Lux.TestHelpers` and the `pytest` fixtures under
//! `priv/python/tests/` support the Elixir and Python sides.
//!
//! The framework deliberately stays inside the standard `cargo test`
//! harness so no extra dependencies are required:
//!
//! ```text
//! cargo test --workspace          # all tests
//! cargo test -p lux_core          # one crate
//! cargo test --test smoke_test    # one integration suite
//! ```
//!
//! It is also surfaced through the Elixir mix task `mix rust.test`, which
//! shells out to `cargo` and forwards any extra arguments. See
//! `lib/mix/tasks/rust/test.ex` for the implementation.

use std::cell::RefCell;
use std::time::{Duration, Instant};

use crate::signal::Signal;

/// A minimal assertion helper that produces a clearer failure message than
/// a bare `assert_eq!` by including the supplied `context`.
///
/// # Examples
///
/// ```
/// use lux_core::testing::assert_eq_with_context;
///
/// assert_eq_with_context("greeting smoke test", "hi", "hi");
/// ```
///
/// # Panics
///
/// Panics if `actual != expected`, the same as [`assert_eq!`].
pub fn assert_eq_with_context<T: PartialEq + std::fmt::Debug>(
    context: &str,
    actual: T,
    expected: T,
) {
    assert!(
        actual == expected,
        "[{context}] assertion failed:\n  left:  {actual:?}\n  right: {expected:?}"
    );
}

/// Builds a sample [`Signal`] suitable for unit tests.
///
/// This mirrors the `sample_struct_data` pytest fixture defined in
/// `priv/python/tests/conftest.py` so the Rust suite has an equivalent
/// canonical fixture.
///
/// # Examples
///
/// ```
/// use lux_core::testing::sample_signal;
///
/// let s = sample_signal();
/// assert_eq!(s.schema_id, "lux.test.sample");
/// assert_eq!(s.metadata.get("sender").map(String::as_str), Some("alice"));
/// ```
#[must_use]
pub fn sample_signal() -> Signal {
    Signal::new("lux.test.sample", "{\"hello\":\"world\"}")
        .with_meta("sender", "alice")
        .with_meta("trace_id", "00000000-0000-0000-0000-000000000001")
}

/// Captures every value passed to it so tests can assert on the entire
/// history of interactions, similar to `Mox.expect/3` on the Elixir side.
///
/// # Examples
///
/// ```
/// use lux_core::testing::Recorder;
///
/// let recorder = Recorder::<&'static str>::new();
/// recorder.record("first");
/// recorder.record("second");
/// assert_eq!(recorder.values(), vec!["first", "second"]);
/// ```
#[derive(Debug, Default)]
pub struct Recorder<T: Clone> {
    inner: RefCell<Vec<T>>,
}

impl<T: Clone> Recorder<T> {
    /// Creates an empty recorder.
    #[must_use]
    pub fn new() -> Self {
        Self {
            inner: RefCell::new(Vec::new()),
        }
    }

    /// Appends `value` to the recorded history.
    pub fn record(&self, value: T) {
        self.inner.borrow_mut().push(value);
    }

    /// Returns a clone of the recorded values in insertion order.
    #[must_use]
    pub fn values(&self) -> Vec<T> {
        self.inner.borrow().clone()
    }

    /// Returns the total number of recorded values.
    #[must_use]
    pub fn len(&self) -> usize {
        self.inner.borrow().len()
    }

    /// Returns `true` when no value has been recorded yet.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.inner.borrow().is_empty()
    }
}

/// Runs `f` and asserts it completes within `max_duration`.
///
/// Useful for guarding latency-sensitive Rust primitives (e.g. signal
/// routing) against accidental regressions.
///
/// # Examples
///
/// ```
/// use std::time::Duration;
/// use lux_core::testing::assert_runs_within;
///
/// assert_runs_within(Duration::from_secs(1), || {
///     // fast no-op
/// });
/// ```
///
/// # Panics
///
/// Panics if `f` takes longer than `max_duration` to execute.
pub fn assert_runs_within<F: FnOnce()>(max_duration: Duration, f: F) {
    let start = Instant::now();
    f();
    let elapsed = start.elapsed();
    assert!(
        elapsed <= max_duration,
        "expected closure to finish within {max_duration:?}, took {elapsed:?}",
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn assert_eq_with_context_passes_on_equality() {
        assert_eq_with_context("smoke", 1, 1);
        assert_eq_with_context("strings", "a", "a");
    }

    #[test]
    #[should_panic(expected = "[mismatch] assertion failed")]
    fn assert_eq_with_context_includes_context_on_failure() {
        assert_eq_with_context("mismatch", 1, 2);
    }

    #[test]
    fn sample_signal_has_expected_shape() {
        let s = sample_signal();
        assert_eq!(s.schema_id, "lux.test.sample");
        assert!(s.payload.contains("hello"));
        assert_eq!(s.metadata.len(), 2);
    }

    #[test]
    fn recorder_starts_empty() {
        let r: Recorder<i32> = Recorder::new();
        assert!(r.is_empty());
        assert_eq!(r.len(), 0);
        assert!(r.values().is_empty());
    }

    #[test]
    fn recorder_preserves_insertion_order() {
        let r: Recorder<i32> = Recorder::new();
        r.record(3);
        r.record(1);
        r.record(2);
        assert_eq!(r.values(), vec![3, 1, 2]);
        assert_eq!(r.len(), 3);
        assert!(!r.is_empty());
    }

    #[test]
    fn assert_runs_within_succeeds_for_fast_closures() {
        assert_runs_within(Duration::from_secs(5), || {
            let _ = (0..100).sum::<i32>();
        });
    }

    #[test]
    #[should_panic(expected = "expected closure to finish within")]
    fn assert_runs_within_panics_when_too_slow() {
        assert_runs_within(Duration::from_millis(0), || {
            std::thread::sleep(Duration::from_millis(20));
        });
    }
}
