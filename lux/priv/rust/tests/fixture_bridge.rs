use lux_rust_examples::normalize_label;

#[test]
fn fixture_bridge_accepts_environment_payloads() {
    let payload = std::env::var("LUX_RUST_FIXTURE_LABEL")
        .unwrap_or_else(|_| " Lux Rust Fixture ".to_string());

    assert_eq!(normalize_label(&payload), "lux_rust_fixture");
}
