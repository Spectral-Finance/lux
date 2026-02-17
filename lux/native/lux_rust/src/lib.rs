use rustler::{Atom, Env, Term, NifResult, Encoder};
use serde::{Deserialize, Serialize};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[derive(Serialize, Deserialize)]
struct RustComponent {
    id: String,
    status: String,
}

#[rustler::nif]
fn handle_request(env: Env, json_payload: String) -> NifResult<Term> {
    let component: RustComponent = match serde_json::from_str(&json_payload) {
        Ok(c) => c,
        Err(_) => return Ok((atoms::error(), "Invalid JSON").encode(env)),
    };

    let result = format!("Processed: {}", component.id);
    Ok((atoms::ok(), result).encode(env))
}

rustler::init!("Elixir.Lux.Rust", [handle_request]);
