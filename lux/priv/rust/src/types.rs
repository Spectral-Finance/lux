use rustler::{Decoder, Encoder, Env, Error, NifResult, NifStruct, Term};

#[derive(Debug, Clone, NifStruct)]
#[module = "Lux.Native.Value"]
pub struct LuxValue {
    pub value_type: String,
    pub data: String,
    pub metadata: Option<String>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "Lux.Native.Map"]
pub struct LuxMap {
    pub entries: Vec<(String, String)>,
    pub size: usize,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "Lux.Native.List"]
pub struct LuxList {
    pub items: Vec<String>,
    pub size: usize,
}

impl LuxValue {
    pub fn new_string(s: &str) -> Self {
        LuxValue {
            value_type: "string".to_string(),
            data: s.to_string(),
            metadata: None,
        }
    }

    pub fn new_number(n: f64) -> Self {
        LuxValue {
            value_type: "number".to_string(),
            data: n.to_string(),
            metadata: None,
        }
    }

    pub fn new_bool(b: bool) -> Self {
        LuxValue {
            value_type: "boolean".to_string(),
            data: b.to_string(),
            metadata: None,
        }
    }

    pub fn is_number(&self) -> bool {
        self.value_type == "number"
    }

    pub fn is_string(&self) -> bool {
        self.value_type == "string"
    }

    pub fn to_float(&self) -> Option<f64> {
        self.data.parse::<f64>().ok()
    }

    pub fn to_int(&self) -> Option<i64> {
        self.data.parse::<i64>().ok()
    }
}

impl LuxMap {
    pub fn new() -> Self {
        LuxMap {
            entries: Vec::new(),
            size: 0,
        }
    }

    pub fn insert(&mut self, key: String, value: String) {
        self.entries.retain(|(k, _)| k != &key);
        self.entries.push((key, value));
        self.size = self.entries.len();
    }

    pub fn get(&self, key: &str) -> Option<&String> {
        self.entries
            .iter()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v)
    }

    pub fn has_key(&self, key: &str) -> bool {
        self.entries.iter().any(|(k, _)| k == key)
    }

    pub fn keys(&self) -> Vec<String> {
        self.entries.iter().map(|(k, _)| k.clone()).collect()
    }

    pub fn values(&self) -> Vec<String> {
        self.entries.iter().map(|(_, v)| v.clone()).collect()
    }
}

impl LuxList {
    pub fn new() -> Self {
        LuxList {
            items: Vec::new(),
            size: 0,
        }
    }

    pub fn push(&mut self, item: String) {
        self.items.push(item);
        self.size = self.items.len();
    }

    pub fn pop(&mut self) -> Option<String> {
        let item = self.items.pop();
        self.size = self.items.len();
        item
    }

    pub fn first(&self) -> Option<&String> {
        self.items.first()
    }

    pub fn last(&self) -> Option<&String> {
        self.items.last()
    }

    pub fn contains(&self, item: &str) -> bool {
        self.items.iter().any(|i| i == item)
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    pub fn len(&self) -> usize {
        self.size
    }
}
