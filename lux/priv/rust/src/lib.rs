use rustler::{Encoder, Env, Error, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn string_length(s: String) -> Result<u64, Error> {
    Ok(s.len() as u64)
}

#[rustler::nif]
fn json_parse(input: String) -> Result<(), Error> {
    let _: serde_json::Value = serde_json::from_str(&input)
        .map_err(|e| Error::Term(Box::new(e.to_string())))?;
    Ok(())
}

rustler::init!("lux_nif", [add, string_length, json_parse]);
