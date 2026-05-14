use base64::{engine::general_purpose, Engine as _};
use serde_json::{json, Value};
use std::{env, process};

fn main() {
    let mut args = env::args().skip(1);
    let operation = args.next().unwrap_or_default();
    let payload = args.next().unwrap_or_default();

    if operation.is_empty() || payload.is_empty() {
        print_error("invalid_args", "usage: lux-core <operation> <base64-json>");
        process::exit(64);
    }

    let decoded = match general_purpose::STANDARD.decode(payload) {
        Ok(decoded) => decoded,
        Err(error) => {
            print_error(
                "invalid_base64",
                format!("could not decode payload: {error}"),
            );
            process::exit(65);
        }
    };

    let input: Value = match serde_json::from_slice(&decoded) {
        Ok(input) => input,
        Err(error) => {
            print_error(
                "invalid_json",
                format!("could not parse JSON payload: {error}"),
            );
            process::exit(65);
        }
    };

    match lux_core::execute(&operation, input) {
        Ok(value) => {
            println!("{}", json!({"ok": true, "value": value}));
        }
        Err(error) => {
            println!("{}", json!({"ok": false, "error": error}));
            process::exit(1);
        }
    }
}

fn print_error(code: &str, message: impl Into<String>) {
    println!(
        "{}",
        json!({"ok": false, "error": {"code": code, "message": message.into()}})
    );
}
