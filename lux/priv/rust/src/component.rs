//! Prism and Beam traits, lifecycle, and NIF dispatch.
//!
//! Handlers receive owned `Converted` values. No BEAM term pointers are
//! retained after the NIF returns.

use crate::async_rt;
use crate::builtins;
use crate::error::{atoms, LuxError};
use crate::types::Converted;
use rustler::{Encoder, Env, Term};
use std::collections::BTreeMap;
use std::sync::{Mutex, OnceLock};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Prism,
    Beam,
}

impl Kind {
    pub fn as_str(self) -> &'static str {
        match self {
            Kind::Prism => "prism",
            Kind::Beam => "beam",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Lifecycle {
    Uninitialized,
    Ready,
    Running,
    Stopped,
}

impl Lifecycle {
    pub fn as_str(self) -> &'static str {
        match self {
            Lifecycle::Uninitialized => "uninitialized",
            Lifecycle::Ready => "ready",
            Lifecycle::Running => "running",
            Lifecycle::Stopped => "stopped",
        }
    }
}

pub type HandlerFn = fn(&Converted, &Converted) -> Result<Converted, LuxError>;
pub type AsyncHandlerFn = fn(
    &Converted,
    &Converted,
) -> std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<Converted, LuxError>> + Send>,
>;

pub struct Component {
    pub id: &'static str,
    pub name: &'static str,
    pub description: &'static str,
    pub kind: Kind,
    pub handler: HandlerFn,
    pub handler_async: Option<AsyncHandlerFn>,
    pub input_schema: Option<Converted>,
    pub output_schema: Option<Converted>,
}

struct Slot {
    component: &'static Component,
    lifecycle: Lifecycle,
}

static REGISTRY: OnceLock<Mutex<BTreeMap<&'static str, Slot>>> = OnceLock::new();

fn registry() -> &'static Mutex<BTreeMap<&'static str, Slot>> {
    REGISTRY.get_or_init(|| Mutex::new(BTreeMap::new()))
}

pub fn init_registry() {
    let mut map = registry().lock().expect("registry poisoned");
    for c in builtins::ALL {
        map.entry(c.id).or_insert(Slot {
            component: *c,
            lifecycle: Lifecycle::Uninitialized,
        });
    }
}

fn resolve_id(id: &str) -> String {
    PathStem::from(id)
}

struct PathStem;
impl PathStem {
    fn from(id: &str) -> String {
        id.strip_suffix(".rs").unwrap_or(id).to_string()
    }
}

fn with_slot<T, F>(id: &str, f: F) -> Result<T, LuxError>
where
    F: FnOnce(&mut Slot) -> Result<T, LuxError>,
{
    let key = resolve_id(id);
    let mut map = registry()
        .lock()
        .map_err(|_| LuxError::runtime("registry poisoned"))?;
    let slot = map
        .get_mut(key.as_str())
        .ok_or_else(|| LuxError::runtime(format!("unknown rust component: {key}")))?;
    f(slot)
}

pub fn init_component(id: &str) -> Result<Lifecycle, LuxError> {
    with_slot(id, |slot| match slot.lifecycle {
        Lifecycle::Stopped => Err(LuxError::runtime(format!(
            "{} is stopped and cannot be re-initialized",
            slot.component.id
        ))),
        Lifecycle::Running => Err(LuxError::runtime(format!(
            "{} is running; wait for completion before init",
            slot.component.id
        ))),
        _ => {
            slot.lifecycle = Lifecycle::Ready;
            Ok(slot.lifecycle)
        }
    })
}

pub fn shutdown_component(id: &str) -> Result<Lifecycle, LuxError> {
    with_slot(id, |slot| {
        slot.lifecycle = Lifecycle::Stopped;
        Ok(slot.lifecycle)
    })
}

pub fn status_component(id: &str) -> Result<Lifecycle, LuxError> {
    with_slot(id, |slot| Ok(slot.lifecycle))
}

fn view_map(id: &str) -> Result<Converted, LuxError> {
    with_slot(id, |slot| {
        let c = slot.component;
        let mut m = BTreeMap::new();
        m.insert("id".into(), Converted::String(c.id.into()));
        m.insert("name".into(), Converted::String(c.name.into()));
        m.insert("description".into(), Converted::String(c.description.into()));
        m.insert("kind".into(), Converted::Atom(c.kind.as_str().into()));
        m.insert(
            "lifecycle".into(),
            Converted::Atom(slot.lifecycle.as_str().into()),
        );
        m.insert(
            "handler".into(),
            Converted::Tuple(vec![
                Converted::Atom("rust".into()),
                Converted::String(c.id.into()),
            ]),
        );
        if let Some(schema) = &c.input_schema {
            m.insert("input_schema".into(), schema.clone());
        }
        if let Some(schema) = &c.output_schema {
            m.insert("output_schema".into(), schema.clone());
        }
        Ok(Converted::Map(m))
    })
}

pub fn run_registered(id: &str, input: Converted, ctx: Converted) -> Result<Converted, LuxError> {
    let (handler, kind_id) = with_slot(id, |slot| {
        match slot.lifecycle {
            Lifecycle::Stopped => {
                return Err(LuxError::runtime(format!("{} is stopped", slot.component.id)))
            }
            Lifecycle::Uninitialized => slot.lifecycle = Lifecycle::Ready,
            _ => {}
        }
        slot.lifecycle = Lifecycle::Running;
        Ok((slot.component.handler, slot.component.id))
    })?;

    let result = handler(&input, &ctx);

    let _ = with_slot(kind_id, |slot| {
        if slot.lifecycle == Lifecycle::Running {
            slot.lifecycle = Lifecycle::Ready;
        }
        Ok(())
    });

    result
}

pub fn run_registered_async(
    id: &str,
    input: Converted,
    ctx: Converted,
) -> Result<Converted, LuxError> {
    let (handler_async, kind_id) = with_slot(id, |slot| {
        match slot.lifecycle {
            Lifecycle::Stopped => {
                return Err(LuxError::runtime(format!("{} is stopped", slot.component.id)))
            }
            Lifecycle::Uninitialized => slot.lifecycle = Lifecycle::Ready,
            _ => {}
        }
        let h = slot.component.handler_async.ok_or_else(|| {
            LuxError::runtime(format!("{} has no async handler", slot.component.id))
        })?;
        slot.lifecycle = Lifecycle::Running;
        Ok((h, slot.component.id))
    })?;

    let fut = handler_async(&input, &ctx);
    let result = async_rt::block_on(fut).map_err(LuxError::runtime)?;

    let _ = with_slot(kind_id, |slot| {
        if slot.lifecycle == Lifecycle::Running {
            slot.lifecycle = Lifecycle::Ready;
        }
        Ok(())
    });

    result
}

pub fn encode_lifecycle(env: Env, life: Lifecycle) -> Term {
    life.as_str().encode(env)
}

pub fn encode_list(env: Env) -> Term {
    let map = match registry().lock() {
        Ok(g) => g,
        Err(_) => return Vec::<Term>::new().encode(env),
    };
    let items: Vec<Term> = map
        .iter()
        .map(|(id, slot)| {
            let mut m = rustler::types::map::map_new(env);
            let _ = m = {
                let m = m.map_put("id".encode(env), id.encode(env)).unwrap_or(m);
                let m = m
                    .map_put("kind".encode(env), slot.component.kind.as_str().encode(env))
                    .unwrap_or(m);
                m.map_put("lifecycle".encode(env), slot.lifecycle.as_str().encode(env))
                    .unwrap_or(m)
            };
            m
        })
        .collect();
    items.encode(env)
}

pub fn encode_view<'a>(env: Env<'a>, id: &str) -> Result<Term<'a>, LuxError> {
    view_map(id)?
        .to_term(env)
        .map_err(|_| LuxError::conversion("failed to encode component view"))
}

pub fn nif_result<'a>(env: Env<'a>, result: Result<Term<'a>, LuxError>) -> Term<'a> {
    match result {
        Ok(term) => (atoms::ok(), term).encode(env),
        Err(e) => (atoms::error(), e.reason_tuple(env)).encode(env),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Converted;

    fn setup() {
        init_registry();
    }

    #[test]
    fn init_then_run_echo() {
        setup();
        assert_eq!(init_component("echo").unwrap(), Lifecycle::Ready);
        let out = run_registered(
            "echo",
            Converted::Integer(7),
            Converted::Map(BTreeMap::new()),
        )
        .unwrap();
        assert_eq!(out, Converted::Integer(7));
        assert_eq!(status_component("echo").unwrap(), Lifecycle::Ready);
    }

    #[test]
    fn unknown_component_errors() {
        setup();
        let err = init_component("nope").unwrap_err();
        assert!(format!("{err}").contains("unknown rust component"));
    }

    #[test]
    fn stopped_cannot_run() {
        setup();
        init_component("hash").unwrap();
        shutdown_component("hash").unwrap();
        let err = run_registered(
            "hash",
            Converted::Nil,
            Converted::Map(BTreeMap::new()),
        )
        .unwrap_err();
        assert!(format!("{err}").contains("stopped"));
    }

    #[test]
    fn fib_prism() {
        setup();
        let out = run_registered(
            "fib",
            Converted::Integer(10),
            Converted::Map(BTreeMap::new()),
        )
        .unwrap();
        assert_eq!(out, Converted::Integer(55));
    }
}
