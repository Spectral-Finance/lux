use rustler::{Env, Term};

mod component;
mod prism;
mod beam;
mod lifecycle;
mod runtime;
mod error;

use component::LuxComponent;
use prism::PrismComponent;
use beam::BeamComponent;

fn load(env: Env, _term: Term) -> bool {
    rustler::resource!(LuxComponent, env);
    rustler::resource!(PrismComponent, env);
    rustler::resource!(BeamComponent, env);
    true
}

rustler::init!(
    "lux_rust",
    [
        prism::define_prism,
        beam::define_beam,
        component::run_component,
    ],
    load = load
);