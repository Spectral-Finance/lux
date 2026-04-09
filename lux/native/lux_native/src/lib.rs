use rustler::{Env, Term, NifResult, Encoder, serde::from_term};
use serde::Deserialize;
use inventory;

pub struct ComponentRegistration {
    pub name: &'static str,
    pub description: &'static str,
    pub input_schema: &'static str,
    pub output_schema: &'static str,
    pub handler: for<'a> fn(Env<'a>, Term<'a>) -> NifResult<Term<'a>>,
}

inventory::collect!(ComponentRegistration);

#[rustler::nif]
pub fn list_components(env: Env) -> NifResult<Term> {
    let names: Vec<String> = inventory::iter::<ComponentRegistration>
        .into_iter()
        .map(|c| c.name.to_string())
        .collect();
    
    Ok(names.encode(env))
}

#[rustler::nif]
pub fn get_component_info(env: Env, name: String) -> NifResult<Term> {
    for registration in inventory::iter::<ComponentRegistration> {
        if registration.name == name {
            let info = rustler::Term::map_new(env);
            let info = info.map_put("name".encode(env), registration.name.encode(env))?;
            let info = info.map_put("description".encode(env), registration.description.encode(env))?;
            let info = info.map_put("input_schema".encode(env), registration.input_schema.encode(env))?;
            let info = info.map_put("output_schema".encode(env), registration.output_schema.encode(env))?;
            return Ok(info);
        }
    }
    Err(rustler::Error::Atom("component_not_found"))
}

#[rustler::nif]
pub fn call_component<'a>(env: Env<'a>, name: String, input: Term<'a>) -> NifResult<Term<'a>> {
    for registration in inventory::iter::<ComponentRegistration> {
        if registration.name == name {
            return (registration.handler)(env, input);
        }
    }
    
    Err(rustler::Error::Atom("component_not_found"))
}

// Example Component using the macro
use lux_native_macros::lux_component;

#[lux_component(name = "Echo", description = "Simple echo component")]
pub fn echo_handler<'a>(_env: Env<'a>, input: Term<'a>) -> NifResult<Term<'a>> {
    Ok(input)
}

#[derive(Deserialize)]
struct MathInput {
    op: String,
    a: i32,
    b: i32,
}

#[lux_component(
    name = "Math", 
    description = "Perform math operations",
    input_schema = r#"{"type":"object","properties":{"op":{"type":"string"},"a":{"type":"number"},"b":{"type":"number"}}}"#
)]
pub fn math_handler<'a>(env: Env<'a>, input: Term<'a>) -> NifResult<Term<'a>> {
    let math_input: MathInput = from_term(input)?;
    let result = match math_input.op.as_str() {
        "add" => math_input.a + math_input.b,
        "subtract" => math_input.a - math_input.b,
        "multiply" => math_input.a * math_input.b,
        "divide" => {
            if math_input.b == 0 {
                return Err(rustler::Error::Atom("division_by_zero"));
            }
            math_input.a / math_input.b
        },
        _ => return Err(rustler::Error::Atom("unsupported_operation")),
    };
    Ok(result.encode(env))
}

rustler::init!("Elixir.Lux.Native");
