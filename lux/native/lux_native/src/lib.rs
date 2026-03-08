mod types;
mod error;

use rustler::{Env, Term, NifResult, Encoder};
use serde_json::Value as JsonValue;

/// Initialize the NIF module
fn on_load(_env: Env, _info: Term) -> bool {
    true
}

// ── Type Conversion ──────────────────────────────────────────────────

/// Convert an Elixir term (JSON string) to a validated Rust type and back.
/// Useful for round-trip validation and transformation.
#[rustler::nif]
fn json_roundtrip(input: String) -> NifResult<String> {
    let value: JsonValue = serde_json::from_str(&input)
        .map_err(|e| rustler::Error::Term(Box::new(format!("JSON parse error: {e}"))))?;
    let output = serde_json::to_string(&value)
        .map_err(|e| rustler::Error::Term(Box::new(format!("JSON serialize error: {e}"))))?;
    Ok(output)
}

/// Validate JSON against a type descriptor.
/// Returns :ok or {:error, reason}.
#[rustler::nif]
fn validate_json(input: String, type_name: String) -> NifResult<(rustler::Atom, String)> {
    match types::validate(&input, &type_name) {
        Ok(()) => Ok((rustler::types::atom::ok(), "valid".to_string())),
        Err(e) => Ok((error::error_atom(), e.to_string())),
    }
}

/// Hash data using SHA-256 (returns hex string)
#[rustler::nif]
fn sha256_hex(data: String) -> String {
    use std::fmt::Write;
    let digest = sha256_digest(data.as_bytes());
    let mut hex = String::with_capacity(64);
    for byte in digest {
        write!(&mut hex, "{byte:02x}").unwrap();
    }
    hex
}

fn sha256_digest(data: &[u8]) -> [u8; 32] {
    // Simple SHA-256 implementation for standalone use
    // In production, consider using ring or sha2 crate
    use std::num::Wrapping;
    
    let k: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    let mut h: [Wrapping<u32>; 8] = [
        Wrapping(0x6a09e667), Wrapping(0xbb67ae85), Wrapping(0x3c6ef372), Wrapping(0xa54ff53a),
        Wrapping(0x510e527f), Wrapping(0x9b05688c), Wrapping(0x1f83d9ab), Wrapping(0x5be0cd19),
    ];

    // Padding
    let bit_len = (data.len() as u64) * 8;
    let mut msg = data.to_vec();
    msg.push(0x80);
    while (msg.len() % 64) != 56 {
        msg.push(0);
    }
    msg.extend_from_slice(&bit_len.to_be_bytes());

    for chunk in msg.chunks_exact(64) {
        let mut w = [Wrapping(0u32); 64];
        for i in 0..16 {
            w[i] = Wrapping(u32::from_be_bytes([chunk[4*i], chunk[4*i+1], chunk[4*i+2], chunk[4*i+3]]));
        }
        for i in 16..64 {
            let s0 = (w[i-15].0.rotate_right(7)) ^ (w[i-15].0.rotate_right(18)) ^ (w[i-15].0 >> 3);
            let s1 = (w[i-2].0.rotate_right(17)) ^ (w[i-2].0.rotate_right(19)) ^ (w[i-2].0 >> 10);
            w[i] = w[i-16] + Wrapping(s0) + w[i-7] + Wrapping(s1);
        }

        let (mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh) =
            (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);

        for i in 0..64 {
            let s1 = Wrapping(e.0.rotate_right(6) ^ e.0.rotate_right(11) ^ e.0.rotate_right(25));
            let ch = Wrapping((e.0 & f.0) ^ ((!e.0) & g.0));
            let temp1 = hh + s1 + ch + Wrapping(k[i]) + w[i];
            let s0 = Wrapping(a.0.rotate_right(2) ^ a.0.rotate_right(13) ^ a.0.rotate_right(22));
            let maj = Wrapping((a.0 & b.0) ^ (a.0 & c.0) ^ (b.0 & c.0));
            let temp2 = s0 + maj;
            hh = g; g = f; f = e; e = d + temp1;
            d = c; c = b; b = a; a = temp1 + temp2;
        }

        h[0] = h[0] + a; h[1] = h[1] + b; h[2] = h[2] + c; h[3] = h[3] + d;
        h[4] = h[4] + e; h[5] = h[5] + f; h[6] = h[6] + g; h[7] = h[7] + hh;
    }

    let mut result = [0u8; 32];
    for i in 0..8 {
        result[4*i..4*i+4].copy_from_slice(&h[i].0.to_be_bytes());
    }
    result
}

/// Benchmark: run json_roundtrip N times, return elapsed microseconds
#[rustler::nif]
fn bench_json_roundtrip(input: String, iterations: u64) -> u64 {
    let start = std::time::Instant::now();
    for _ in 0..iterations {
        let _: JsonValue = serde_json::from_str(&input).unwrap();
    }
    start.elapsed().as_micros() as u64
}

rustler::init!("Elixir.Lux.Native");
