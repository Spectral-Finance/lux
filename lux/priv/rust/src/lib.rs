/// Lux Rust Runtime
///
/// This module provides utility functions for Rust code
/// executed within the Lux multi-agent framework.

/// A simple computation result wrapper
pub struct ComputationResult<T> {
    pub value: T,
    pub description: String,
}

impl<T: std::fmt::Display> ComputationResult<T> {
    pub fn new(value: T, description: &str) -> Self {
        Self {
            value,
            description: description.to_string(),
        }
    }
}

/// Resolves dependencies from a Cargo.toml manifest
pub fn resolve_dependencies(manifest: &str) -> Vec<String> {
    let mut deps = Vec::new();
    for line in manifest.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with('[') && trimmed != "[package]" {
            break;
        }
    }
    deps
}

/// Version comparison utility
pub fn compare_versions(a: &str, b: &str) -> std::cmp::Ordering {
    let a_parts: Vec<u32> = a.split('.').filter_map(|p| p.parse().ok()).collect();
    let b_parts: Vec<u32> = b.split('.').filter_map(|p| p.parse().ok()).collect();

    for (av, bv) in a_parts.iter().zip(b_parts.iter()) {
        match av.cmp(bv) {
            std::cmp::Ordering::Equal => continue,
            other => return other,
        }
    }
    a_parts.len().cmp(&b_parts.len())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_computation_result() {
        let result = ComputationResult::new(42, "The answer");
        assert_eq!(result.value, 42);
        assert_eq!(result.description, "The answer");
    }

    #[test]
    fn test_version_comparison() {
        assert_eq!(compare_versions("1.0.0", "2.0.0"), std::cmp::Ordering::Less);
        assert_eq!(compare_versions("2.0.0", "1.0.0"), std::cmp::Ordering::Greater);
        assert_eq!(compare_versions("1.0.0", "1.0.0"), std::cmp::Ordering::Equal);
    }
}
