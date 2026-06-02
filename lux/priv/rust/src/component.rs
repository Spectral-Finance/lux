use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentMeta {
    pub name: String,
    pub kind: String,
    pub version: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentState {
    pub status: String,
    pub initialized: bool,
}

pub trait Component {
    fn meta(&self) -> ComponentMeta;
    fn init(&mut self);
    fn shutdown(&mut self);
    fn is_initialized(&self) -> bool;
    fn name(&self) -> &str;
    fn kind(&self) -> &str;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrismInput {
    pub data: String,
    pub metadata: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrismOutput {
    pub data: String,
    pub status: String,
    pub errors: Vec<String>,
}

pub trait Prism: Component {
    fn handler(&self, input: PrismInput) -> PrismOutput;
    fn validate_input(&self, input: &PrismInput) -> bool;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeamInput {
    pub data: Vec<String>,
    pub config: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeamOutput {
    pub results: Vec<String>,
    pub metrics: Option<String>,
}

pub trait Beam: Component {
    fn execute(&self, input: BeamInput) -> BeamOutput;
    fn can_execute(&self, input: &BeamInput) -> bool;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentLifecycle {
    pub state: String,
    pub transitions: Vec<String>,
    pub error_count: usize,
}

pub trait LifecycleManager {
    fn transition(&mut self, event: &str) -> Result<String, String>;
    fn current_state(&self) -> &str;
    fn allowed_transitions(&self) -> Vec<String>;
}

pub struct BTreeRegistry<T: Component> {
    entries: std::collections::BTreeMap<String, T>,
    lookup: std::collections::HashMap<String, String>,
}

impl<T: Component> BTreeRegistry<T> {
    pub fn new() -> Self {
        BTreeRegistry {
            entries: std::collections::BTreeMap::new(),
            lookup: std::collections::HashMap::new(),
        }
    }

    pub fn register(&mut self, component: T) -> bool {
        let name = component.name().to_string();
        if self.lookup.contains_key(&name) {
            return false;
        }
        let key = format!("{}:{}", component.kind(), name);
        self.lookup.insert(name.clone(), key.clone());
        self.entries.insert(key, component);
        true
    }

    pub fn unregister(&mut self, name: &str) -> bool {
        if let Some(key) = self.lookup.remove(name) {
            self.entries.remove(&key);
            true
        } else {
            false
        }
    }

    pub fn get(&self, name: &str) -> Option<&T> {
        if let Some(key) = self.lookup.get(name) {
            self.entries.get(key)
        } else {
            None
        }
    }

    pub fn get_mut(&mut self, name: &str) -> Option<&mut T> {
        if let Some(key) = self.lookup.get(name) {
            self.entries.get_mut(key)
        } else {
            None
        }
    }

    pub fn list_by_kind(&self, kind: &str) -> Vec<&T> {
        let prefix = format!("{}:", kind);
        self.entries
            .range(prefix.clone()..)
            .take_while(|(k, _)| k.starts_with(&prefix))
            .map(|(_, v)| v)
            .collect()
    }

    pub fn all(&self) -> Vec<&T> {
        self.entries.values().collect()
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Clone)]
    struct TestComp {
        name: String,
        kind: String,
    }

    impl Component for TestComp {
        fn meta(&self) -> ComponentMeta {
            ComponentMeta {
                name: self.name.clone(),
                kind: self.kind.clone(),
                version: "1.0".into(),
                description: "test".into(),
            }
        }
        fn init(&mut self) {}
        fn shutdown(&mut self) {}
        fn is_initialized(&self) -> bool { true }
        fn name(&self) -> &str { &self.name }
        fn kind(&self) -> &str { &self.kind }
    }

    #[test]
    fn test_registry_register_and_get() {
        let mut reg = BTreeRegistry::new();
        assert!(reg.is_empty());

        let c = TestComp { name: "my_lens".into(), kind: "lens".into() };
        assert!(reg.register(c));
        assert_eq!(reg.len(), 1);

        let found = reg.get("my_lens");
        assert!(found.is_some());
        assert_eq!(found.unwrap().name(), "my_lens");
    }

    #[test]
    fn test_registry_duplicate_register() {
        let mut reg = BTreeRegistry::new();
        let c1 = TestComp { name: "dup".into(), kind: "prism".into() };
        let c2 = TestComp { name: "dup".into(), kind: "lens".into() };

        assert!(reg.register(c1));
        assert!(!reg.register(c2));
        assert_eq!(reg.len(), 1);
    }

    #[test]
    fn test_registry_unregister() {
        let mut reg = BTreeRegistry::new();
        let c = TestComp { name: "temp".into(), kind: "prism".into() };
        reg.register(c);

        assert!(reg.unregister("temp"));
        assert!(reg.is_empty());
        assert!(!reg.unregister("temp"));
    }

    #[test]
    fn test_registry_list_by_kind() {
        let mut reg = BTreeRegistry::new();
        reg.register(TestComp { name: "p1".into(), kind: "prism".into() });
        reg.register(TestComp { name: "l1".into(), kind: "lens".into() });
        reg.register(TestComp { name: "p2".into(), kind: "prism".into() });

        let prisms = reg.list_by_kind("prism");
        assert_eq!(prisms.len(), 2);

        let lenses = reg.list_by_kind("lens");
        assert_eq!(lenses.len(), 1);
    }

    #[test]
    fn test_component_meta() {
        let meta = ComponentMeta {
            name: "test_comp".into(),
            kind: "lens".into(),
            version: "0.1.0".into(),
            description: "A test component".into(),
        };
        assert_eq!(meta.name, "test_comp");
        assert_eq!(meta.kind, "lens");
    }

    #[test]
    fn test_prism_trait_objects() {
        let input = PrismInput {
            data: "test_data".into(),
            metadata: Some("meta".into()),
        };
        assert_eq!(input.data, "test_data");
        assert!(input.metadata.is_some());

        let output = PrismOutput {
            data: "result".into(),
            status: "ok".into(),
            errors: vec![],
        };
        assert_eq!(output.status, "ok");
        assert!(output.errors.is_empty());
    }
}
