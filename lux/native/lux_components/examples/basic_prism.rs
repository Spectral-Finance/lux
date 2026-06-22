use async_trait::async_trait;
use lux_components::{Prism, Context, ComponentResult};
use serde_json::{json, Value};

/// A simple echoing Prism component written in Rust.
pub struct EchoPrism;

impl EchoPrism {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Prism for EchoPrism {
    fn id(&self) -> &str {
        "echo-prism-1"
    }
    
    fn name(&self) -> &str {
        "EchoPrism"
    }
    
    fn description(&self) -> &str {
        "A basic prism that echoes its input."
    }

    async fn init(&mut self) -> ComponentResult<()> {
        println!("EchoPrism: Initializing...");
        Ok(())
    }
    
    async fn start(&mut self) -> ComponentResult<()> {
        println!("EchoPrism: Starting...");
        Ok(())
    }
    
    async fn stop(&mut self) -> ComponentResult<()> {
        println!("EchoPrism: Stopping...");
        Ok(())
    }
    
    async fn handler(&self, input: Value, _context: &Context) -> ComponentResult<Value> {
        println!("EchoPrism: Handling input: {}", input);
        
        Ok(json!({
            "status": "success",
            "echo": input
        }))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut prism = EchoPrism::new();
    
    // Component Lifecycle
    prism.init().await?;
    prism.start().await?;
    
    println!("Prism Info: {} - {}", prism.name(), prism.description());
    
    // Execute Prism
    let ctx = Context::new("exec_1".to_string(), "step_1".to_string(), json!({}));
    let payload = json!({"message": "Hello from Lux Rust components!"});
    
    let result = prism.handler(payload, &ctx).await?;
    println!("Result: {}", result);
    
    prism.stop().await?;
    
    Ok(())
}
