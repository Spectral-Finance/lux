//! NIF bindings exported to Elixir as `Lux.Rust`.
//!
//! Each `#[rustler::nif]` function becomes a function on the Elixir module
//! declared in `rustler::init!` (see `lib.rs`). All fallible operations return
//! `Result<T, LuxError>`, which Rustler encodes as `{:ok, _} | {:error, _}`.
//!
//! ## Memory safety
//!
//! * No raw pointers cross the boundary; Rustler's `Encoder`/`Decoder` own all
//!   data while it is on the BEAM heap.
//! * `catch_unwind` wraps the compute-heavy NIFs so a Rust panic becomes an
//!   `{:error, %{kind: :panic, ...}}` tuple instead of crashing the VM.
//! * Binaries are borrowed (`&[u8]`) from the BEAM heap and never mutated.
//!
//! ## Testability
//!
//! The `#[rustler::nif]` macro inlines the function body into a wrapper and
//! does not keep the original as a callable item, so the pure logic lives in
//! plain `*_impl` functions that the unit tests exercise directly. The NIF
//! wrappers are thin one-liners that delegate to them.

use rustler::{Binary, Term};

use crate::convert;
use crate::error::LuxError;

// ---------------------------------------------------------------------------
// Pure logic (unit-testable without a BEAM)
// ---------------------------------------------------------------------------

/// Add two integers.
fn add_impl(a: i64, b: i64) -> i64 {
    a + b
}

/// Multiply two integers.
fn multiply_impl(a: i64, b: i64) -> i64 {
    a * b
}

/// Sum a list of integers.
fn sum_list_impl(values: &[i64]) -> i64 {
    values.iter().copied().sum()
}

/// Reverse a list of integers.
fn reverse_list_impl(values: Vec<i64>) -> Vec<i64> {
    values.into_iter().rev().collect()
}

/// Sum the bytes of a binary slice.
fn binary_checksum_impl(data: &[u8]) -> i64 {
    data.iter().map(|&b| b as i64).sum()
}

/// Uppercase a string.
fn to_uppercase_impl(input: &str) -> String {
    input.to_uppercase()
}

/// Join strings with a separator.
fn join_strings_impl(parts: &[String], separator: &str) -> String {
    parts.join(separator)
}

/// Compute the factorial of `n` iteratively.
///
/// Returns an error for negative input or overflow instead of panicking.
fn factorial_impl(n: i64) -> Result<i64, LuxError> {
    if n < 0 {
        return Err(LuxError::invalid_argument_detail(
            "factorial is undefined for negative numbers",
            format!("received n = {n}"),
        ));
    }
    let mut acc: i64 = 1;
    for i in 2..=n {
        acc = acc
            .checked_mul(i)
            .ok_or_else(|| LuxError::internal("factorial overflowed i64"))?;
    }
    Ok(acc)
}

/// Parse a string into an integer, returning a structured error on failure.
fn parse_int_impl(input: &str) -> Result<i64, LuxError> {
    input.trim().parse::<i64>().map_err(|e| {
        LuxError::invalid_argument_detail(
            "could not parse integer",
            format!("input = {input:?}: {e}"),
        )
    })
}

/// Run a compute-heavy operation under `catch_unwind` so a panic becomes an
/// error tuple instead of crashing the BEAM.
fn safe_compute_impl(should_panic: bool) -> Result<i64, LuxError> {
    let result = std::panic::catch_unwind(|| {
        if should_panic {
            panic!("intentional panic inside safe_compute");
        }
        99_i64
    });

    match result {
        Ok(v) => Ok(v),
        Err(payload) => {
            let msg = payload
                .downcast_ref::<&str>()
                .map(|s| s.to_string())
                .or_else(|| payload.downcast_ref::<String>().cloned())
                .unwrap_or_else(|| "unknown panic".to_string());
            Err(LuxError::Panic { message: msg })
        }
    }
}

// ---------------------------------------------------------------------------
// NIF wrappers (thin, delegate to *_impl)
// ---------------------------------------------------------------------------

/// Return the version of the compiled Rust core as a string.
///
/// Useful for diagnostics and to confirm the NIF actually loaded (rather than
/// the Elixir fallback stub). Returns `{:ok, version}` to match the contract
/// documented on `Lux.Rust.core_version/0`.
#[rustler::nif]
fn core_version() -> Result<String, LuxError> {
    Ok(crate::CORE_VERSION.to_string())
}

/// Add two integers. Pure type-conversion smoke test for the FFI boundary.
#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    add_impl(a, b)
}

/// Multiply two integers.
#[rustler::nif]
fn multiply(a: i64, b: i64) -> i64 {
    multiply_impl(a, b)
}

/// Sum a list of integers. Demonstrates list decoding + fold.
#[rustler::nif]
fn sum_list(values: Vec<i64>) -> i64 {
    sum_list_impl(&values)
}

/// Reverse a list of integers. Demonstrates list encode/decode roundtrip.
#[rustler::nif]
fn reverse_list(values: Vec<i64>) -> Vec<i64> {
    reverse_list_impl(values)
}

/// Sum the bytes of a binary. Demonstrates borrowing a BEAM binary without
/// copying it.
#[rustler::nif]
fn binary_checksum(data: Binary) -> i64 {
    binary_checksum_impl(data.as_slice())
}

/// Convert a string to uppercase. Demonstrates string decode + encode.
#[rustler::nif]
fn to_uppercase(input: String) -> String {
    to_uppercase_impl(&input)
}

/// Join a list of strings with a separator.
#[rustler::nif]
fn join_strings(parts: Vec<String>, separator: String) -> String {
    join_strings_impl(&parts, &separator)
}

/// Compute the factorial of `n` iteratively.
///
/// Returns `{:error, reason}` for negative input instead of panicking, which
/// demonstrates the error-propagation framework end to end.
#[rustler::nif]
fn factorial(n: i64) -> Result<i64, LuxError> {
    factorial_impl(n)
}

/// Parse a string into an integer, returning a structured error on failure.
///
/// Demonstrates converting a Rust-level validation failure into the Lux error
/// framework rather than raising.
#[rustler::nif]
fn parse_int(input: String) -> Result<i64, LuxError> {
    parse_int_impl(&input)
}

/// Read a required integer key from a map term.
///
/// Demonstrates the `map_get` conversion helper and structured errors when the
/// key is missing or the value has the wrong type.
#[rustler::nif]
fn map_get_int(map: Term, key: String) -> Result<i64, LuxError> {
    convert::map_get::<i64>(map, &key).map_err(|_| {
        LuxError::invalid_argument_detail(
            "missing or non-integer key in map",
            format!("key = {key:?}"),
        )
    })
}

/// Run a compute-heavy operation under `catch_unwind` so a panic becomes an
/// error tuple instead of crashing the BEAM.
///
/// If `should_panic` is true the closure deliberately panics; the NIF must
/// still return `{:error, %{kind: :panic, ...}}` rather than aborting.
#[rustler::nif]
fn safe_compute(should_panic: bool) -> Result<i64, LuxError> {
    safe_compute_impl(should_panic)
}

/// Called by Rustler when the NIF shared object is loaded into the BEAM.
///
/// Returns `true` to signal a successful load. This is the hook where future
/// resource types / ETS tables would be created.
pub(crate) fn on_load() -> bool {
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_works() {
        assert_eq!(add_impl(2, 3), 5);
        assert_eq!(add_impl(-1, 1), 0);
    }

    #[test]
    fn multiply_works() {
        assert_eq!(multiply_impl(4, 5), 20);
        assert_eq!(multiply_impl(0, 999), 0);
    }

    #[test]
    fn sum_and_reverse() {
        let v = vec![1, 2, 3, 4];
        assert_eq!(sum_list_impl(&v), 10);
        assert_eq!(reverse_list_impl(v), vec![4, 3, 2, 1]);
    }

    #[test]
    fn binary_checksum_works() {
        assert_eq!(binary_checksum_impl(&[1, 2, 3]), 6);
        assert_eq!(binary_checksum_impl(&[]), 0);
        assert_eq!(binary_checksum_impl(&[255]), 255);
    }

    #[test]
    fn string_ops_work() {
        assert_eq!(to_uppercase_impl("hello"), "HELLO");
        assert_eq!(
            join_strings_impl(&["a".into(), "b".into()], "-"),
            "a-b"
        );
    }

    #[test]
    fn factorial_ok() {
        assert_eq!(factorial_impl(0), Ok(1));
        assert_eq!(factorial_impl(5), Ok(120));
        assert_eq!(factorial_impl(20), Ok(2_432_902_008_176_640_000));
    }

    #[test]
    fn factorial_negative_is_error() {
        match factorial_impl(-1) {
            Err(e) => assert_eq!(e.kind(), "invalid_argument"),
            Ok(_) => panic!("expected error for negative factorial"),
        }
    }

    #[test]
    fn factorial_overflow_is_error() {
        // 21! overflows i64.
        match factorial_impl(21) {
            Err(e) => assert_eq!(e.kind(), "internal"),
            Ok(_) => panic!("expected overflow error"),
        }
    }

    #[test]
    fn parse_int_ok_and_err() {
        assert_eq!(parse_int_impl("42"), Ok(42));
        assert_eq!(parse_int_impl("  7  "), Ok(7));
        assert!(parse_int_impl("not a number").is_err());
    }

    #[test]
    fn safe_compute_handles_panic() {
        assert_eq!(safe_compute_impl(false), Ok(99));
        match safe_compute_impl(true) {
            Err(e) => assert_eq!(e.kind(), "panic"),
            Ok(_) => panic!("expected panic error"),
        }
    }
}