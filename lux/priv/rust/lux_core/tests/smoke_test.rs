//! Integration smoke tests for `lux_core`.
//!
//! These tests exercise the crate exactly the way an external consumer
//! would: through its public API only. They live under `tests/` so they
//! compile as a separate binary, catching missing `pub` items or hidden
//! coupling between modules.

use std::time::Duration;

use lux_core::signal::Signal;
use lux_core::testing::{assert_eq_with_context, assert_runs_within, sample_signal, Recorder};
use lux_core::{greet, VERSION};

#[test]
fn version_is_non_empty() {
    assert!(!VERSION.is_empty(), "VERSION must be set by Cargo");
}

#[test]
fn greet_round_trip() {
    let msg = greet("integration");
    assert!(msg.contains("integration"));
    assert!(msg.starts_with("Hello from lux_core"));
}

#[test]
fn sample_signal_is_a_valid_signal() {
    let s: Signal = sample_signal();
    assert_eq_with_context("schema id", s.schema_id.as_str(), "lux.test.sample");
    assert!(!s.is_empty(), "sample signal must carry a payload");
}

#[test]
fn signals_can_be_recorded_and_replayed() {
    let recorder: Recorder<Signal> = Recorder::new();
    recorder.record(Signal::new("a", "1"));
    recorder.record(Signal::new("b", "2"));
    recorder.record(Signal::new("c", "3"));

    let values = recorder.values();
    assert_eq!(values.len(), 3);
    assert_eq!(values[0].schema_id, "a");
    assert_eq!(values[2].payload, "3");
}

#[test]
fn signal_construction_is_fast() {
    // Guard rail: building a million signals should comfortably finish
    // within a second on any developer machine. If this regresses we
    // probably introduced an accidental allocation in the hot path.
    assert_runs_within(Duration::from_secs(2), || {
        let mut last_len = 0;
        for i in 0..1_000_000 {
            let s = Signal::new("bench", i.to_string());
            last_len = s.payload.len();
        }
        assert!(last_len > 0);
    });
}
