use dashmap::DashMap;
use std::sync::Arc;

/// A thread-safe, high-performance registry for Lux components.
/// Uses DashMap under the hood to minimize lock contention for fast, concurrent access.
pub struct Registry<T: ?Sized> {
    items: DashMap<String, Arc<T>>,
}

impl<T: ?Sized> Default for Registry<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T: ?Sized> Registry<T> {
    /// Creates a new, empty Registry.
    pub fn new() -> Self {
        Self {
            items: DashMap::new(),
        }
    }

    /// Registers a new item with the given ID.
    pub fn register(&self, id: String, item: Arc<T>) {
        self.items.insert(id, item);
    }

    /// Retrieves an item by its ID.
    pub fn get(&self, id: &str) -> Option<Arc<T>> {
        self.items.get(id).map(|r| r.value().clone())
    }

    /// Removes an item by its ID, returning it if it existed.
    pub fn remove(&self, id: &str) -> Option<Arc<T>> {
        self.items.remove(id).map(|(_, v)| v)
    }

    /// Checks if an item with the given ID exists.
    pub fn contains(&self, id: &str) -> bool {
        self.items.contains_key(id)
    }
}
