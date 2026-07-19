use thiserror::Error;
#[derive(Error, Debug)]
pub enum LuxError {
    #[error("Serialization: {0}")] Serialization(String),
    #[error("Type: {0}")] Type(String),
    #[error("Crypto: {0}")] Crypto(String),
    #[error("Cargo: {0}")] Cargo(String),
    #[error("Test: {0}")] Test(String),
    #[error("Component: {0}")] Component(String),
    #[error("Runtime: {0}")] Runtime(String),
}
impl From<LuxError> for rustler::Error {
    fn from(err: LuxError) -> Self { rustler::Error::Term(Box::new(err.to_string())) }
}
