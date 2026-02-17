use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
pub enum LuxType {
    Value(String),
}

impl LuxType {
    pub fn new(value: String) -> Self {
        LuxType::Value(value)
    }

    pub fn to_rust(&self) -> Result<String, Box<dyn std::error::Error>> {
        match self {
            LuxType::Value(value) => :erlang.nif_call(:rust_nifs, :to_rust, [value]),
        }
    }

    pub fn from_rust(rust_value: String) -> Result<Self, Box<dyn std::error::Error>> {
        Ok(LuxType::new(rust_value))
    }
}