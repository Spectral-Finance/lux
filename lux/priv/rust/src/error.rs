use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(tag = "type", content = "message")]
pub enum RustError {
    #[error("Type conversion error: {0}")]
    TypeConversion(String),

    #[error("Execution error: {0}")]
    Execution(String),

    #[error("Function not found: {0}")]
    FunctionNotFound(String),

    #[error("Argument error: {0}")]
    InvalidArgument(String),

    #[error("Runtime panic caught: {0}")]
    Panic(String),

    #[error("IO error: {0}")]
    Io(String),

    #[error("Serialization error: {0}")]
    Serialization(String),
}

impl From<serde_json::Error> for RustError {
    fn from(err: serde_json::Error) -> Self {
        RustError::Serialization(err.to_string())
    }
}

impl From<std::io::Error> for RustError {
    fn from(err: std::io::Error) -> Self {
        RustError::Io(err.to_string())
    }
}

pub type Result<T> = std::result::Result<T, RustError>;
