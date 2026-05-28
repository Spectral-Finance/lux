use std::collections::HashMap;
use std::fs;
use std::path::Path;

/// Cargo package management helper
struct CargoManager {
    project_root: String,
    dependencies: std::collections::HashMap<String, String>,
}

impl CargoManager {
    fn new() -> Self {
        CargoManager {
            project_root: String::from("."),
            dependencies: HashMap::new(),
        }
    }
    
    fn add_dependency(&mut self, name: &str, version: &str) {
        self.dependencies.insert(name.to_string(), version.to_string());
    }
}

fn main() {
    let mut manager = CargoManager::new();
    manager.add_dependency("tokio", "1.0");
    manager.add_dependency("serde", "1.0");
}