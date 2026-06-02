#[derive(Debug, Clone)]
pub struct LuxNativeError {
    pub message: String,
    pub code: Option<i64>,
}

impl LuxNativeError {
    pub fn new(message: &str) -> Self {
        LuxNativeError {
            message: message.to_string(),
            code: None,
        }
    }

    pub fn with_code(message: &str, code: i64) -> Self {
        LuxNativeError {
            message: message.to_string(),
            code: Some(code),
        }
    }
}

impl std::fmt::Display for LuxNativeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self.code {
            Some(code) => write!(f, "[{}] {}", code, self.message),
            None => write!(f, "{}", self.message),
        }
    }
}

impl std::error::Error for LuxNativeError {}
