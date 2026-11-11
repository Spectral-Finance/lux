//! Native Rust trait definition and async lifecycle bridge for Lux components (#103).

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LifecycleState {
    Initialized,
    Running,
    Stopped,
}

pub trait LuxComponent: Send + Sync {
    type Input: for<'de> Deserialize<'de> + Send;
    type Output: Serialize + Send;

    fn name(&self) -> &'static str;
    fn init(&mut self) -> Result<(), String> {
        Ok(())
    }
    fn execute(&self, input: Self::Input) -> Result<Self::Output, String>;
    fn shutdown(&mut self) -> Result<(), String> {
        Ok(())
    }
}
