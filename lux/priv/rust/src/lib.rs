use serde_json::Value;
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ComponentKind {
    Prism,
    Beam,
    Lens,
}

#[derive(Debug, Error)]
pub enum LuxError {
    #[error("invalid input: {0}")]
    InvalidInput(String),
    #[error("component failed: {0}")]
    ComponentFailed(String),
}

pub trait LuxComponent {
    fn name(&self) -> &'static str;
    fn kind(&self) -> ComponentKind;
    fn handle(&self, input: Value) -> Result<Value, LuxError>;

    fn init(&self) -> Result<(), LuxError> {
        Ok(())
    }

    fn shutdown(&self) -> Result<(), LuxError> {
        Ok(())
    }
}

pub trait LuxPrism: LuxComponent {}
pub trait LuxBeam: LuxComponent {}
pub trait LuxLens: LuxComponent {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LifecycleState {
    Defined,
    Compiled,
    Loaded,
    Started,
    Called,
    Stopped,
}

pub async fn handle_async<C>(component: C, input: Value) -> Result<Value, LuxError>
where
    C: LuxComponent + Send + Sync + 'static,
{
    component.handle(input)
}
