use thiserror::Error;

#[derive(Error, Debug)]
pub enum ComponentError {
    #[error("Initialization error: {0}")]
    InitError(String),
    
    #[error("Execution error: {0}")]
    ExecutionError(String),
    
    #[error("Lifecycle error: {0}")]
    LifecycleError(String),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    
    #[error("Unknown error: {0}")]
    Unknown(String),
}

pub type ComponentResult<T> = Result<T, ComponentError>;
