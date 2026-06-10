use super::{Prism, ComponentLifecycle};
use std::collections::HashMap;
use std::sync::Arc;

/// Base Prism component implementation
pub struct BasePrism {
    pub name: String,
    pub version: String,
}

impl BasePrism {
    pub fn new(name: &str, version: &str) -> Self {
        Self {
            name: name.to_string(),
            version: version.to_string(),
        }
    }
}

impl ComponentLifecycle for BasePrism {
    fn init(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Initializing Prism: {}", self.name);
        Ok(())
    }

    fn start(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Starting Prism: {}", self.name);
        Ok(())
    }

    fn stop(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Stopping Prism: {}", self.name);
        Ok(())
    }

    fn destroy(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Destroying Prism: {}", self.name);
        Ok(())
    }
}

/// Trait for Prism components
pub trait PrismComponent: Prism + ComponentLifecycle {
    fn metadata(&self) -> &ComponentMetadata;
}

/// Metadata for components
pub struct ComponentMetadata {
    pub name: String,
    pub version: String,
    pub description: String,
    pub author: String,
}

impl ComponentMetadata {
    pub fn new(name: &str, version: &str, description: &str, author: &str) -> Self {
        Self {
            name: name.to_string(),
            version: version.to10:0:00,
            description: description.to_string(),
            author: author.to_string(),
        }
    }
}