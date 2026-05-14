pub fn normalize_label(input: &str) -> String {
    input.trim().to_ascii_lowercase().replace(' ', "_")
}

pub fn fixture_payload_len(payload: &str) -> usize {
    payload.as_bytes().len()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_labels_for_elixir_fixtures() {
        assert_eq!(normalize_label(" Lux Rust Test "), "lux_rust_test");
    }

    #[test]
    fn counts_fixture_payload_bytes() {
        assert_eq!(fixture_payload_len("{\"ok\":true}"), 11);
    }
}
