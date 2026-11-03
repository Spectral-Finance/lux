use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use crate::error::{Result, RustError};

/// Dynamic Value representation bridging Elixir and Rust terms
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(untagged)]
pub enum LuxValue {
    Nil,
    Boolean(bool),
    Integer(i64),
    Float(f64),
    String(String),
    Binary(Vec<u8>),
    List(Vec<LuxValue>),
    Map(HashMap<String, LuxValue>),
}

impl LuxValue {
    pub fn is_nil(&self) -> bool {
        matches!(self, LuxValue::Nil)
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            LuxValue::Integer(i) => Some(*i),
            _ => None,
        }
    }

    pub fn as_f64(&self) -> Option<f64> {
        match self {
            LuxValue::Float(f) => Some(*f),
            LuxValue::Integer(i) => Some(*i as f64),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            LuxValue::String(s) => Some(s.as_str()),
            _ => None,
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match self {
            LuxValue::Boolean(b) => Some(*b),
            _ => None,
        }
    }

    pub fn as_map(&self) -> Option<&HashMap<String, LuxValue>> {
        match self {
            LuxValue::Map(m) => Some(m),
            _ => None,
        }
    }

    pub fn as_list(&self) -> Option<&[LuxValue]> {
        match self {
            LuxValue::List(l) => Some(l.as_slice()),
            _ => None,
        }
    }
}

impl From<Value> for LuxValue {
    fn from(val: Value) -> Self {
        match val {
            Value::Null => LuxValue::Nil,
            Value::Bool(b) => LuxValue::Boolean(b),
            Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    LuxValue::Integer(i)
                } else if let Some(f) = n.as_f64() {
                    LuxValue::Float(f)
                } else {
                    LuxValue::Nil
                }
            }
            Value::String(s) => LuxValue::String(s),
            Value::Array(arr) => LuxValue::List(arr.into_iter().map(Into::into).collect()),
            Value::Object(obj) => {
                let map = obj.into_iter().map(|(k, v)| (k, v.into())).collect();
                LuxValue::Map(map)
            }
        }
    }
}

impl From<LuxValue> for Value {
    fn from(val: LuxValue) -> Self {
        match val {
            LuxValue::Nil => Value::Null,
            LuxValue::Boolean(b) => Value::Bool(b),
            LuxValue::Integer(i) => Value::Number(i.into()),
            LuxValue::Float(f) => serde_json::Number::from_f64(f)
                .map(Value::Number)
                .unwrap_or(Value::Null),
            LuxValue::String(s) => Value::String(s),
            LuxValue::Binary(bytes) => Value::Array(bytes.into_iter().map(|b| Value::Number((b as i64).into())).collect()),
            LuxValue::List(l) => Value::Array(l.into_iter().map(Into::into).collect()),
            LuxValue::Map(m) => Value::Object(m.into_iter().map(|(k, v)| (k, v.into())).collect()),
        }
    }
}

pub trait FromLuxValue: Sized {
    fn from_lux_value(val: LuxValue) -> Result<Self>;
}

pub trait ToLuxValue {
    fn to_lux_value(self) -> LuxValue;
}

// Implementations for primitives
impl FromLuxValue for i64 {
    fn from_lux_value(val: LuxValue) -> Result<Self> {
        val.as_i64()
            .ok_or_else(|| RustError::TypeConversion(format!("Expected integer, got {:?}", val)))
    }
}

impl ToLuxValue for i64 {
    fn to_lux_value(self) -> LuxValue {
        LuxValue::Integer(self)
    }
}

impl FromLuxValue for f64 {
    fn from_lux_value(val: LuxValue) -> Result<Self> {
        val.as_f64()
            .ok_or_else(|| RustError::TypeConversion(format!("Expected float, got {:?}", val)))
    }
}

impl ToLuxValue for f64 {
    fn to_lux_value(self) -> LuxValue {
        LuxValue::Float(self)
    }
}

impl FromLuxValue for String {
    fn from_lux_value(val: LuxValue) -> Result<Self> {
        match val {
            LuxValue::String(s) => Ok(s),
            other => Err(RustError::TypeConversion(format!("Expected string, got {:?}", other))),
        }
    }
}

impl ToLuxValue for String {
    fn to_lux_value(self) -> LuxValue {
        LuxValue::String(self)
    }
}

impl ToLuxValue for &str {
    fn to_lux_value(self) -> LuxValue {
        LuxValue::String(self.to_string())
    }
}

impl FromLuxValue for bool {
    fn from_lux_value(val: LuxValue) -> Result<Self> {
        val.as_bool()
            .ok_or_else(|| RustError::TypeConversion(format!("Expected boolean, got {:?}", val)))
    }
}

impl ToLuxValue for bool {
    fn to_lux_value(self) -> LuxValue {
        LuxValue::Boolean(self)
    }
}
