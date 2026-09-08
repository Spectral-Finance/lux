//! Built-in Prism and Beam implementations used as examples and tests.

use crate::component::{AsyncHandlerFn, Component, HandlerFn, Kind};
use crate::error::LuxError;
use crate::types::Converted;
use std::collections::BTreeMap;
use std::hash::{Hash, Hasher};
use std::time::Duration;

fn echo(input: &Converted, _ctx: &Converted) -> Result<Converted, LuxError> {
    Ok(input.clone())
}

fn hash_term(input: &Converted, _ctx: &Converted) -> Result<Converted, LuxError> {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    format!("{input:?}").hash(&mut hasher);
    Ok(Converted::Integer(hasher.finish() as i64))
}

fn fib_n(input: &Converted, _ctx: &Converted) -> Result<Converted, LuxError> {
    let n = match input {
        Converted::Integer(n) => *n,
        Converted::Map(m) => m
            .get("n")
            .ok_or_else(|| LuxError::runtime("missing n"))?
            .as_i64()?,
        other => {
            return Err(LuxError::type_error(
                "integer or map with n",
                other.type_name(),
            ))
        }
    };
    if n < 0 {
        return Err(LuxError::runtime("n must be >= 0"));
    }
    if n > 92 {
        return Err(LuxError::runtime("n must be <= 92 so the result fits in u64"));
    }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    for _ in 0..n {
        let next = a.checked_add(b).ok_or_else(|| LuxError::runtime("overflow"))?;
        a = b;
        b = next;
    }
    Ok(Converted::Integer(a as i64))
}

fn map_get(input: &Converted, _ctx: &Converted) -> Result<Converted, LuxError> {
    let map = input.as_map()?;
    let key = match map.get("key") {
        Some(Converted::String(s) | Converted::Atom(s)) => s.clone(),
        Some(other) => other.type_name().to_string(),
        None => return Err(LuxError::runtime("missing key")),
    };
    let target = map
        .get("map")
        .ok_or_else(|| LuxError::runtime("missing map"))?;
    Ok(target.map_get(&key)?.clone())
}

fn sequence(input: &Converted, ctx: &Converted) -> Result<Converted, LuxError> {
    let hashed = hash_term(input, ctx)?;
    echo(&hashed, ctx)
}

fn sleep_sync(input: &Converted, _ctx: &Converted) -> Result<Converted, LuxError> {
    let ms = match input {
        Converted::Integer(n) => *n,
        Converted::Map(m) => m
            .get("ms")
            .or_else(|| m.get("millis"))
            .and_then(|v| v.as_i64().ok())
            .unwrap_or(1),
        _ => 1,
    };
    let ms = ms.clamp(0, 5_000) as u64;
    std::thread::sleep(Duration::from_millis(ms));
    let mut m = BTreeMap::new();
    m.insert("ok".into(), Converted::Bool(true));
    m.insert("ms".into(), Converted::Integer(ms as i64));
    Ok(Converted::Map(m))
}

fn sleep_async(input: &Converted, ctx: &Converted) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Converted, LuxError>> + Send>> {
    let owned_input = input.clone();
    let _ctx = ctx.clone();
    Box::pin(async move {
        let ms = match &owned_input {
            Converted::Integer(n) => *n,
            Converted::Map(m) => m
                .get("ms")
                .or_else(|| m.get("millis"))
                .and_then(|v| v.as_i64().ok())
                .unwrap_or(1),
            _ => 1,
        };
        let ms = ms.clamp(0, 5_000) as u64;
        tokio::time::sleep(Duration::from_millis(ms)).await;
        let mut m = BTreeMap::new();
        m.insert("ok".into(), Converted::Bool(true));
        m.insert("ms".into(), Converted::Integer(ms as i64));
        Ok(Converted::Map(m))
    })
}

const ECHO: Component = Component {
    id: "echo",
    name: "Echo",
    description: "Returns the converted input unchanged.",
    kind: Kind::Prism,
    handler: echo as HandlerFn,
    handler_async: None,
    input_schema: None,
    output_schema: None,
};

const HASH: Component = Component {
    id: "hash",
    name: "Hash",
    description: "Default hasher over a converted term.",
    kind: Kind::Prism,
    handler: hash_term as HandlerFn,
    handler_async: None,
    input_schema: None,
    output_schema: None,
};

const FIB: Component = Component {
    id: "fib",
    name: "Fibonacci",
    description: "Fibonacci(n) for n <= 92.",
    kind: Kind::Prism,
    handler: fib_n as HandlerFn,
    handler_async: None,
    input_schema: None,
    output_schema: None,
};

const MAP_GET: Component = Component {
    id: "map_get",
    name: "Map Get",
    description: "Looks up map[key] from %{map: ..., key: ...}.",
    kind: Kind::Prism,
    handler: map_get as HandlerFn,
    handler_async: None,
    input_schema: None,
    output_schema: None,
};

const SLEEP: Component = Component {
    id: "sleep",
    name: "Sleep",
    description: "Sleeps then returns %{ok: true}. Async uses Tokio.",
    kind: Kind::Prism,
    handler: sleep_sync as HandlerFn,
    handler_async: Some(sleep_async as AsyncHandlerFn),
    input_schema: None,
    output_schema: None,
};

const SEQUENCE: Component = Component {
    id: "sequence",
    name: "Hash then Echo",
    description: "Beam that hashes input then echoes the digest.",
    kind: Kind::Beam,
    handler: sequence as HandlerFn,
    handler_async: None,
    input_schema: None,
    output_schema: None,
};

pub static ALL: &[&Component] = &[&ECHO, &HASH, &FIB, &MAP_GET, &SLEEP, &SEQUENCE];
