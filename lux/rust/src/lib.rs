/// Returns true if the input string contains the Kanji character for "zero" (é›¶).
pub fn contains_zero_kanji(input: &str) -> bool {
    input.chars().any(|c| c == '\u{96F6}')
}

/// Counts the number of ASCII digits in a string.
pub fn count_ascii_digits(input: &str) -> usize {
    input.chars().filter(|c| c.is_ascii_digit()).count()
}

/// Returns the sum of all ASCII digit characters in a string.
pub fn sum_ascii_digits(input: &str) -> i32 {
    input
        .chars()
        .filter(|c| c.is_ascii_digit())
        .map(|c| c.to_digit(10).unwrap() as i32)
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_contains_zero_kanji_positive() {
        assert!(contains_zero_kanji("hello\u{96F6}world"));
    }

    #[test]
    fn test_contains_zero_kanji_negative() {
        assert!(!contains_zero_kanji("hello world"));
    }

    #[test]
    fn test_count_ascii_digits() {
        assert_eq!(count_ascii_digits("abc123"), 3);
        assert_eq!(count_ascii_digits("no digits"), 0);
        assert_eq!(count_ascii_digits("42"), 2);
    }

    #[test]
    fn test_sum_ascii_digits() {
        assert_eq!(sum_ascii_digits("123"), 6);
        assert_eq!(sum_ascii_digits("0"), 0);
        assert_eq!(sum_ascii_digits(""), 0);
    }
}
