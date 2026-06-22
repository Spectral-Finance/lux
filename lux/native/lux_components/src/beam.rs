use async_trait::async_trait;
use serde_json::Value;

use crate::context::Context;
use crate::error::ComponentResult;

/// Core trait defining a Beam component in Lux.
/// Beams are responsible for transforming payloads.
#[async_trait]
pub trait Beam: Send + Sync {
    /// Returns the unique identifier of the Beam.
    fn id(&self) -> &str;
    
    /// Returns the name of the Beam.
    fn name(&self) -> &str;
    
    /// Returns a description of what this Beam does.
    fn description(&self) -> &str;

    /// Lifecycle hook: Called once when the Beam is initialized.
    async fn init(&mut self) -> ComponentResult<()> {
        Ok(())
    }

    /// Lifecycle hook: Called when the Beam starts.
    async fn start(&mut self) -> ComponentResult<()> {
        Ok(())
    }

    /// Lifecycle hook: Called when the Beam stops.
    async fn stop(&mut self) -> ComponentResult<()> {
        Ok(())
    }

    /// The core transformation handler. 
    /// Processes the input and returns a transformed output.
    async fn transform(&self, input: Value, context: &Context) -> ComponentResult<Value>;
}
