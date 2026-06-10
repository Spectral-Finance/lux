pub mod components;

/// Main library entry point for Lux Rust components
pub use components::{Prism, Beam, ComponentLifecycle};

/// Re-export important types for component definition
pub use components::prism::{PrismComponent, ComponentMetadata, BasePrism};
pub use components::beam::{BaseBeam, AsyncComponent};

#[cfg(test)]
mod tests {
    use super::*;
    use components::prism::BasePrism;
    
    #[test]
    fn test_prism_creation() {
        let prism = BasePrism::new("test_prism", "1.0.0");
        assert_eq!(prism.name, "test_prism");
        assert_eq!(prism.version, "1.0.0");
    }
}