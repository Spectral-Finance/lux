use super::{Beam, ComponentLifecycle};
use std::future::Future;
use std::pin::Pin;

/// Base Beam component implementation
pub struct BaseBeam {
    pub name: String,
    pub version: String,
}

impl BaseBeam {
    pub fn new(name: &str, version: &str) -> Self {
        Self {
            name: name.to_string(),
            version: version.to_string(),
        }
    }
}

impl ComponentLifecycle for BaseBeam {
    fn init(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Initializing Beam: {}", self.name);
        Ok(())
    }

    fn start(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Starting Beam: {}", self.name);
        Ok(())
    }

    fn stop(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Stopping Beam: {}", self.name);
        Ok(())
    }

    fn destroy(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Destroying Beam: {}", self.name);
        Ok(())
    }
}

/// Trait for async component execution
pub trait AsyncComponent: Beam + ComponentLifecycle {
    fn execute_async(&self) -> Pin<Box<dyn Future<Output = ()>>> {
        Box::pin(async { () })
    }
}