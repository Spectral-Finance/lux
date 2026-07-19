use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
pub struct CargoPackage { pub name: String, pub version: String, pub edition: String, pub description: Option<String> }
#[derive(Debug, Serialize, Deserialize)]
pub struct CargoConfig {
    pub package: CargoPackage,
    pub dependencies: HashMap<String, DependencySpec>,
    #[serde(default)] pub features: HashMap<String, Vec<String>>,
}
#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
pub enum DependencySpec {
    Simple(String),
    Detailed { version: Option<String>, git: Option<String>, path: Option<String>, branch: Option<String>, features: Option<Vec<String>>, optional: Option<bool> },
}

impl CargoConfig {
    pub fn new(name: &str, version: &str) -> Self {
        Self {
            package: CargoPackage { name: name.into(), version: version.into(), edition: "2021".into(), description: None },
            dependencies: HashMap::new(), features: HashMap::new(),
        }
    }
    pub fn add_dependency(&mut self, name: &str, version: &str) {
        self.dependencies.insert(name.into(), DependencySpec::Simple(version.into()));
    }
    pub fn to_toml_string(&self) -> Result<String, String> {
        toml::to_string_pretty(self).map_err(|e| e.to_string())
    }
    pub fn from_toml(input: &str) -> Result<Self, String> {
        toml::from_str(input).map_err(|e| e.to_string())
    }
}

pub fn resolve_dependencies(cargo_toml: &str) -> Result<Vec<(String, String)>, String> {
    let config = CargoConfig::from_toml(cargo_toml)?;
    Ok(config.dependencies.iter()
        .map(|(name, spec)| {
            let version = match spec {
                DependencySpec::Simple(v) => v.clone(),
                DependencySpec::Detailed { version, .. } => version.clone().unwrap_or("*".into()),
            };
            (name.clone(), version)
        }).collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn test_create() { let c = CargoConfig::new("test","0.1.0"); assert_eq!(c.package.name,"test"); }
    #[test] fn test_dep() { let mut c = CargoConfig::new("x","1.0"); c.add_dependency("serde","1"); assert!(c.dependencies.contains_key("serde")); }
    #[test] fn test_roundtrip() { let mut c = CargoConfig::new("t","0.1.0"); c.add_dependency("serde","1"); let p = CargoConfig::from_toml(&c.to_toml_string().unwrap()).unwrap(); assert_eq!(p.package.name,"t"); }
}
