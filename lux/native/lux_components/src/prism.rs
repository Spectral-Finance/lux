use async_trait::async_trait;
use serde_json::Value;

use crate::context::Context;
use crate::error::ComponentResult;

/// Core trait defining a Prism component in Lux.
/// Prisms are modular, functional components designed to perform specific tasks.
#[async_trait]
pub trait Prism: Send + Sync {
    /// Returns the unique identifier of the Prism.
    fn id(&self) -> &str;
    
    /// Returns the name of the Prism.
    fn name(&self) -> &str;
    
    /// Returns a description of what this Prism does.
    fn description(&self) -> &str;

    /// Lifecycle hook: Called once when the Prism is initialized.
    async fn init(&mut self) -> ComponentResult<()> {
        Ok(())
    }

    /// Lifecycle hook: Called when the Prism starts.
    async fn start(&mut self) -> ComponentResult<()> {
        Ok(())
    }

    /// Lifecycle hook: Called when the Prism stops.
    async fn stop(&mut self) -> ComponentResult<()> {
        Ok(())
    }

    /// The core execution handler. 
    /// Processes the input using the provided context.
    async fn handler(&self, input: Value, context: &Context) -> ComponentResult<Value>;
}
