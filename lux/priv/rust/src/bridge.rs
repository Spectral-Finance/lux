use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use crate::error::{Result, RustError};
use crate::types::LuxValue;

/// Registry of built-in native Rust functions accessible by Lux
pub struct FunctionRegistry {
    handlers: HashMap<String, Box<dyn Fn(LuxValue) -> Result<LuxValue> + Send + Sync>>,
}

impl FunctionRegistry {
    pub fn new() -> Self {
        let mut registry = Self {
            handlers: HashMap::new(),
        };
        registry.register_defaults();
        registry
    }

    pub fn register<F>(&mut self, name: &str, handler: F)
    where
        F: Fn(LuxValue) -> Result<LuxValue> + Send + Sync + 'static,
    {
        self.handlers.insert(name.to_string(), Box::new(handler));
    }

    pub fn call(&self, name: &str, args: LuxValue) -> Result<LuxValue> {
        let handler = self.handlers.get(name).ok_or_else(|| {
            RustError::FunctionNotFound(format!("Function '{}' not found in registry", name))
        })?;

        // Memory safety: catch any internal panics to prevent BEAM host crashing
        let result = catch_unwind(AssertUnwindSafe(|| handler(args)));

        match result {
            Ok(exec_res) => exec_res,
            Err(panic_payload) => {
                let msg = if let Some(s) = panic_payload.downcast_ref::<&str>() {
                    s.to_string()
                } else if let Some(s) = panic_payload.downcast_ref::<String>() {
                    s.clone()
                } else {
                    "Unknown panic".to_string()
                };
                Err(RustError::Panic(msg))
            }
        }
    }

    fn register_defaults(&mut self) {
        // Fast numeric add
        self.register("math.add", |args| {
            if let LuxValue::Map(map) = args {
                let a = map.get("a").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let b = map.get("b").and_then(|v| v.as_f64()).unwrap_or(0.0);
                Ok(LuxValue::Float(a + b))
            } else if let LuxValue::List(list) = args {
                let sum: f64 = list.iter().filter_map(|v| v.as_f64()).sum();
                Ok(LuxValue::Float(sum))
            } else {
                Err(RustError::InvalidArgument("Expected map or list for math.add".to_string()))
            }
        });

        // Fast vector dot product
        self.register("math.dot_product", |args| {
            if let LuxValue::Map(map) = args {
                let a = map.get("a").and_then(|v| v.as_list()).ok_or_else(|| {
                    RustError::InvalidArgument("Missing vector 'a'".to_string())
                })?;
                let b = map.get("b").and_then(|v| v.as_list()).ok_or_else(|| {
                    RustError::InvalidArgument("Missing vector 'b'".to_string())
                })?;

                if a.len() != b.len() {
                    return Err(RustError::InvalidArgument(format!(
                        "Vectors must have same length: {} vs {}",
                        a.len(),
                        b.len()
                    )));
                }

                let mut dot = 0.0;
                for (x, y) in a.iter().zip(b.iter()) {
                    let vx = x.as_f64().unwrap_or(0.0);
                    let vy = y.as_f64().unwrap_or(0.0);
                    dot += vx * vy;
                }

                Ok(LuxValue::Float(dot))
            } else {
                Err(RustError::InvalidArgument("Expected map with keys 'a' and 'b'".to_string()))
            }
        });

        // String echo / upper
        self.register("string.to_uppercase", |args| {
            if let LuxValue::String(s) = args {
                Ok(LuxValue::String(s.to_uppercase()))
            } else if let LuxValue::Map(m) = args {
                let s = m.get("text").and_then(|v| v.as_str()).unwrap_or("");
                Ok(LuxValue::String(s.to_uppercase()))
            } else {
                Err(RustError::InvalidArgument("Expected string or map with 'text'".to_string()))
            }
        });

        // Fast Fibonacci calculation in native Rust
        self.register("math.fibonacci", |args| {
            let n = match args {
                LuxValue::Integer(i) => i,
                LuxValue::Map(m) => m.get("n").and_then(|v| v.as_i64()).unwrap_or(0),
                _ => return Err(RustError::InvalidArgument("Expected integer or map with 'n'".to_string())),
            };

            if n < 0 {
                return Err(RustError::InvalidArgument("n must be non-negative".to_string()));
            }

            let res = fib(n as u64);
            Ok(LuxValue::Integer(res as i64))
        });
    }
}

fn fib(n: u64) -> u64 {
    if n <= 1 {
        return n;
    }
    let mut a = 0;
    let mut b = 1;
    for _ in 2..=n {
        let c = a + b;
        a = b;
        b = c;
    }
    b
}
