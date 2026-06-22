use serde::{Deserialize, Serialize};

/// Represents the lifecycle states of a component (Prism or Beam).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LifecycleState {
    Uninitialized,
    Initialized,
    Running,
    Stopped,
    Error,
}

/// A trait for managing a component's lifecycle.
pub trait Lifecycle {
    /// Gets the current state of the component.
    fn current_state(&self) -> LifecycleState;
    
    /// Sets the current state of the component.
    fn set_state(&mut self, state: LifecycleState);
}
