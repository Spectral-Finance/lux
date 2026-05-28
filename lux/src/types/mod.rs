//! Lux Type System
//!
//! This module provides the core type system for Lux, enabling seamless
//! data exchange between Elixir and Rust with advanced type mapping,
//! serialization, and bidirectional conversion utilities.

pub mod mapping;
pub mod serialization;
pub mod definitions;

/// Re-export commonly used items
pub use mapping::{TypeMapper, TypeMapping};
pub use serialization::{Serializer, Deserializer};
pub use definitions::{LuxType, StructDefinition, EnumDefinition};
pub use serde::{Serialize, Deserialize};