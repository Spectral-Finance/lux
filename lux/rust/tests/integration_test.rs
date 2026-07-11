use lux_rust::{contains_zero_kanji, count_ascii_digits, sum_ascii_digits};

#[test]
fn integration_test_contains_zero_kanji() {
    assert!(contains_zero_kanji("test\u{96F6}"));
    assert!(!contains_zero_kanji("no kanji"));
}

#[test]
fn integration_test_count_digits() {
    assert_eq!(count_ascii_digits("a1b2c3"), 3);
}

#[test]
fn integration_test_sum_digits() {
    assert_eq!(sum_ascii_digits("111"), 3);
}
