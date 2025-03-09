use crate::LuxComponent;
use async_trait::async_trait;
use rustler::Error;
use serde_json::Value;

#[derive(Debug)]
pub struct EchoComponent {
    #[allow(dead_code)]
    config: Value,
}

impl EchoComponent {
    pub fn new(config: Value) -> Self {
        Self { config }
    }
}

#[async_trait]
impl LuxComponent for EchoComponent {
    async fn initialize(&self) -> Result<(), Error> {
        Ok(())
    }

    async fn process(&self, input: Value) -> Result<Value, Error> {
        Ok(input)
    }

    async fn cleanup(&self) -> Result<(), Error> {
        Ok(())
    }
} 