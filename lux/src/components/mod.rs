pub mod prism;
pub mod beam;

use std::future::Future;
use std::pin::Pin;

/// Trait for defining Lux Prisms
pub trait Prism {
    type Input;
    type Output;
    type Error;

    /// Process method that components must implement
    fn process(&self, input: Self::Input) -> Result<Self::Output, Self::Error>;
}

/// Trait for defining Lux Beams (workflows)
pub trait Beam {
    type Context;
    type Output;
    type Error;

    /// Execute method for beam components
    fn execute(&self, context: Self::Context) -> Pin<Box<dyn Future<Output = Result<Self::Output, Self::Error>>>;
}

/// Lifecycle trait for components
pub trait ComponentLifecycle {
    fn init(&mut self) -> Result<(), Box<dyn std::error::Error>>;
    fn start(&mut self) -> Result<(), Box<dyn std::error::Error>>;
    fn stop(&mut self) -> Result<(), Box<dyn std::error::Error>>;
    fn destroy(&mut self) -> Result<(), Box<dyn std::error::Error>>;
}