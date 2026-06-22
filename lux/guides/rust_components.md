# Rust Component Definition

Lux allows you to define core primitives, like `Prism` and `Beam`, using Rust to leverage high performance and strong typing. The Rust components run directly within native bounds and communicate asynchronously.

## The Trait System

The core framework exposes several traits that you can implement to define a Rust component:

### 1. `Prism`
A `Prism` is a component that handles input payloads and performs an action, usually returning an output payload.

```rust
#[async_trait]
pub trait Prism: Send + Sync {
    fn id(&self) -> &str;
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    async fn init(&mut self) -> ComponentResult<()>;
    async fn start(&mut self) -> ComponentResult<()>;
    async fn stop(&mut self) -> ComponentResult<()>;
    async fn handler(&self, input: serde_json::Value, context: &Context) -> ComponentResult<serde_json::Value>;
}
```

### 2. `Beam`
A `Beam` is used to transform data from one format into another inside of pipelines.

```rust
#[async_trait]
pub trait Beam: Send + Sync {
    fn id(&self) -> &str;
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    async fn init(&mut self) -> ComponentResult<()>;
    async fn start(&mut self) -> ComponentResult<()>;
    async fn stop(&mut self) -> ComponentResult<()>;
    async fn transform(&self, input: serde_json::Value, context: &Context) -> ComponentResult<serde_json::Value>;
}
```

## Creating a Rust Prism Example

Here is an example of a simple `EchoPrism` built using the Rust trait system.

```rust
use async_trait::async_trait;
use lux_components::{Prism, Context, ComponentResult};
use serde_json::{json, Value};

pub struct EchoPrism;

#[async_trait]
impl Prism for EchoPrism {
    fn id(&self) -> &str { "echo-1" }
    fn name(&self) -> &str { "EchoPrism" }
    fn description(&self) -> &str { "Echoes input" }
    
    async fn handler(&self, input: Value, _context: &Context) -> ComponentResult<Value> {
        Ok(json!({ "echo": input }))
    }
}
```

## Performance Optimizations

Internally, Lux Rust components can be stored in a thread-safe highly concurrent `Registry` powered by `DashMap`. This ensures that component retrieval does not bottleneck parallel workflows inside the framework.

```rust
use lux_components::Registry;
use lux_components::Prism;

let registry: Registry<dyn Prism> = Registry::new();
registry.register("my_echo_prism".to_string(), std::sync::Arc::new(EchoPrism));
```
