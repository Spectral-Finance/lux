use std::collections::HashMap;
use std::path::Path;
use std::fs;
use std::process::Command;
use serde::{Deserialize, Serialize};
use toml::from_str;
use toml::Value;

#[derive(Debug, Serialize, Deserialize)]
pub struct CargoConfig {
    pub name: String,
    pub version: String,
    pub dependencies: HashMap<String, String>,
}

impl CargoConfig {
    pub fn new(name: String, version: String) -> Self {
        CargoConfig {
            name,
            version,
            dependencies: HashMap::new(),
        }
    }
    
    pub fn add_dependency(&mut self, name: String, version: String) {
        self.dependencies.insert(name, version);
    }
    
    pub fn remove_dependency(&mut self, name: &str) {
        self.dependencies.remove(name);
    }
    
    pub fn update_dependency(&mut self, name: &str, version: &str) {
        self.dependencies.insert(name.to_string(), version.to_string());
    }
}

pub struct CargoManager {
    config: CargoConfig,
}

impl CargoManager {
    pub fn new(name: String, version: String) -> Self {
        CargoManager {
            config: CargoConfig::new(name, version),
        }
    }
    
    pub fn add_dependency(&mut self, name: String, version: String) {
        self.config.add_dependency(name, version);
    }
    
    pub fn remove_dependency(&mut self, name: &str) {
        self.config.remove_dependency(name);
    }
    
    pub fn update_dependency(&mut self, name: &str, version: &str) {
        self.config.update_dependency(name, version);
    }
}

pub fn read_cargo_toml(path: &Path) -> Result<Value, Box<dyn std::error::Error>> {
    let contents = fs::read_to_string(path)?;
    let cargo_toml: Value = from_str(&contents)?;
    Ok(cargo_toml)
}

pub fn write_cargo_tomfile(config: &CargoConfig, path: &Path) -> std::io::Result<()> {
    let toml_content = format!(r#"
[package]
name = "{}"
version = "{}"

[dependencies]
"#, config.name, config.version);
    
    fs::write(path, toml_content)
}

pub fn init_cargo_project(name: &str, version: &str, path: &Path) -> std::io::Result<()> {
    let cargo_toml_path = path.join("Cargo.toml");
    let mut file = std::fs::File::create(cargo_toml_path)?;
    
    let toml_content = format!(r#"
[package]
name = "{}"
version = "{}"

[dependencies]
# Add your dependencies here
"#, name, version);
    
    file.write_all(toml_content.as_bytes())?;
    file.flush()?;
    Ok(())
}

pub fn add_dependency(name: &str, version: &str, path: &Path) -> std::io::Result<()> {
    let mut cargo_toml = fs::read_to_string(path)?;
    cargo_toml.push_str(&format!("\n{} = \"{}\"", name, version));
    fs::write(path, cargo_toml)?;
    Ok(())
}

pub fn build_project(path: &Path) -> Result<(), std::io::Error> {
    let output = Command::new("cargo")
        .current_dir(path)
        .arg("build")
        .output()?;
    
    if !output.status.success() {
        return Err(std::io::Error::new(std::io::ErrorKind::Other, "Build failed"));
    }
    
    Ok(())
}

pub fn test_project(path: &Path) -> Result<(), std::io::Error> {
    let output = Command::new("cargo")
        .current_dir(path)
        .arg("test")
        .output()?;
    
    if !output.status.success() {
        return Err(std::io::Error::new(std::io::ErrorKind::Other, "Tests failed"));
    }
    
    Ok(())
}

pub fn update_cargo_config(path: &Path, name: &str, version: &str) -> Result<(), std::io::Error> {
    let config_path = path.join("Cargo.toml");
    let mut config_content = fs::read_to_string(&config_path)?;
    
    // Update package info
    let new_content = format!(r#"
[package]
name = "{}"
version = "{}"

[dependencies]
"#, name, version);
    
    fs::write(config_path, new_content)?;
    Ok(())
}