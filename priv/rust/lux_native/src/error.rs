use thiserror::Error;

#[derive(Error, Debug)]
pub enum LuxError {
    #[error("Serialization error: {0}")]
    Serialization(String),
    #[error("Deserialization error: {0}")]
    Deserialization(String),
    #[error("Type conversion error: {0}")]
    TypeConversion(String),
    #[error("Cryptographic error: {0}")]
    Crypto(String),
    #[error("Runtime error: {0}")]
    Runtime(String),
}

impl From<LuxError> for rustler::Error {
    fn from(err: LuxError) -> Self {
        rustler::Error::Term(Box::new(err.to_string()))
    }
}
