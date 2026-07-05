use async_trait::async_trait;
use rustler::{Env, NifResult, Term, Error};

/// Error type for components
#[derive(Debug)]
pub enum ComponentError {
    Execution(String),
    Lifecycle(String),
}

impl From<ComponentError> for Error {
    fn from(err: ComponentError) -> Self {
        match err {
            ComponentError::Execution(e) => Error::Term(Box::new(format!("Execution Error: {}", e))),
            ComponentError::Lifecycle(e) => Error::Term(Box::new(format!("Lifecycle Error: {}", e))),
        }
    }
}

/// The Component trait defines the lifecycle and execution interface
/// for native Lux components (Prisms/Beams) written in Rust.
///
/// Async/await is supported via the `async_trait` macro.
#[async_trait]
pub trait Component {
    type Input;
    type Output;

    /// Called when the component is initialized.
    /// Can be used to allocate resources, connect to databases, etc.
    async fn init(&mut self) -> Result<(), ComponentError> {
        Ok(())
    }

    /// The core execution logic of the component.
    async fn execute(&self, input: Self::Input) -> Result<Self::Output, ComponentError>;

    /// Called when the component is terminated.
    /// Can be used to clean up resources.
    async fn terminate(&mut self) -> Result<(), ComponentError> {
        Ok(())
    }
}

/// Example of a performance-optimized Rust Prism component.
pub struct MathPrism;

#[async_trait]
impl Component for MathPrism {
    type Input = (i64, i64);
    type Output = i64;

    async fn execute(&self, input: Self::Input) -> Result<Self::Output, ComponentError> {
        // High-performance native math operation
        let (a, b) = input;
        a.checked_add(b)
            .ok_or_else(|| ComponentError::Execution("Integer overflow".to_string()))
    }
}
