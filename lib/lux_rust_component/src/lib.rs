use lux_rs_component::{LuxComponent, Component, ComponentContext, ComponentResult, LuxComponentError};
use lux_rs_component::Component;
use lux_rs_component::ComponentContext;
use lux_rs_component::ComponentResult;
use lux_rs_component::LuxComponentError;

// Component trait definition
pub trait Component {
    fn handle_signal(&mut self, ctx: &ComponentContext) -> ComponentResult<Signal> {
        self.on_signal(ctx.signal())
    }
}

// Component implementation
pub struct MyRustComponent {
    context: ComponentContext,
    component: Component,
}

impl Component for MyRustComponent {
    fn handle_signal(&mut self, ctx: &ComponentContext) -> ComponentResult<Signal> {
        self.handle_signal(ctx.signal())
    }
}

// Rust component definition
pub struct LuxComponent {
    pub name: String,
    pub fn new(name: &str) -> Self {
        LuxComponent {
            name: name.to_string()
        }
    }
}

// Signal trait implementation
impl Component for Signal {
    fn handle_signal(&self, ctx: &ComponentContext) -> ComponentResult<Signal> {
        self.handle_signal(ctx.signal())
    }
}