use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct ComponentConfig {
    pub name: String,
    #[serde(rename = "type")]
    pub component_type: String,
    pub description: Option<String>,
    pub config: serde_json::Value,
}

pub fn register_component(name: &str, config_json: &str) -> Result<String, String> {
    let config: ComponentConfig = serde_json::from_str(config_json)
        .map_err(|e| format!("Invalid component config: {e}"))?;

    if config.name != name {
        return Err(format!("Name mismatch: {name} vs {}", config.name));
    }

    let registered = serde_json::json!({
        "status": "registered",
        "name": config.name,
        "type": config.component_type,
        "timestamp": chrono_now(),
    });

    serde_json::to_string_pretty(&registered)
        .map_err(|e| format!("Serialization error: {e}"))
}

fn chrono_now() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let dur = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    format!("{}", dur.as_secs())
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PrismDef {
    pub name: String,
    pub description: String,
    pub input_schema: serde_json::Value,
    pub output_schema: serde_json::Value,
    pub handler: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BeamDef {
    pub name: String,
    pub description: String,
    pub prisms: Vec<String>,
    pub config: serde_json::Value,
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn test_register_component() {
        let config = r#"{"name":"test","type":"prism","description":"test prism","config":{}}"#;
        let result = register_component("test", config).unwrap();
        assert!(result.contains("registered"));
    }
    #[test] fn test_name_mismatch() {
        let config = r#"{"name":"other","type":"prism","config":{}}"#;
        assert!(register_component("test", config).is_err());
    }
    #[test] fn test_prism_def_serde() {
        let def = PrismDef {
            name: "my-prism".into(),
            description: "test".into(),
            input_schema: serde_json::json!({"type":"object"}),
            output_schema: serde_json::json!({"type":"object"}),
            handler: "handle".into(),
        };
        let json = serde_json::to_string(&def).unwrap();
        let parsed: PrismDef = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.name, "my-prism");
    }
}
