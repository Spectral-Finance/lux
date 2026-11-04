//! Native Rust Component Traits and Lifecycle Management for Lux (`Spectral-Finance/lux#103`).

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LifecycleState {
    Registered,
    Initialized,
    Running,
    Stopped,
    Degraded,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentContext {
    pub component_id: String,
    pub agent_name: Option<String>,
    pub zero_copy: bool,
}

/// Core trait for defining a native Rust Prism in Lux.
pub trait PrismComponent: Send + Sync {
    fn name(&self) -> &str;
    fn init(&mut self) -> Result<LifecycleState, String> {
        Ok(LifecycleState::Initialized)
    }
    fn handle(&self, input: Value, ctx: &ComponentContext) -> Result<Value, String>;
    fn terminate(&mut self) -> Result<LifecycleState, String> {
        Ok(LifecycleState::Stopped)
    }
}

/// Core trait for defining a native Rust Beam workflow in Lux.
pub trait BeamComponent: Send + Sync {
    fn name(&self) -> &str;
    fn steps(&self) -> Vec<String>;
    fn execute_step(&self, step: &str, payload: Value, ctx: &ComponentContext) -> Result<Value, String>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    struct PortfolioRiskPrism;

    impl PrismComponent for PortfolioRiskPrism {
        fn name(&self) -> &str {
            "PortfolioRiskPrism"
        }

        fn handle(&self, input: Value, _ctx: &ComponentContext) -> Result<Value, String> {
            let exposure = input.get("exposure").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let var_99 = exposure * 0.045;
            Ok(json!({ "var_99": var_99, "status": "ok" }))
        }
    }

    #[test]
    fn test_prism_trait_lifecycle_and_execution() {
        let mut prism = PortfolioRiskPrism;
        assert_eq!(prism.init().unwrap(), LifecycleState::Initialized);
        let ctx = ComponentContext {
            component_id: "risk_prism".to_string(),
            agent_name: Some("RiskAgent".to_string()),
            zero_copy: true,
        };
        let out = prism.handle(json!({ "exposure": 1000.0 }), &ctx).unwrap();
        assert_eq!(out["var_99"], json!(45.0));
        assert_eq!(prism.terminate().unwrap(), LifecycleState::Stopped);
    }
}
