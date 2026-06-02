#[cfg(feature = "nif")]
use rustler::NifStruct;
use serde::{Deserialize, Serialize};

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.Value")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuxValue {
    pub value_type: String,
    pub data: String,
    pub metadata: Option<String>,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.Map")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuxMap {
    pub entries: Vec<(String, String)>,
    pub size: usize,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.List")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuxList {
    pub items: Vec<String>,
    pub size: usize,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.TypeSchema")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeSchema {
    pub kind: String,
    pub fields: Vec<FieldDescriptor>,
    pub constraints: Option<String>,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.FieldDescriptor")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldDescriptor {
    pub name: String,
    pub rust_type: String,
    pub is_optional: bool,
    pub default_value: Option<String>,
    pub validators: Vec<String>,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.EnumSchema")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnumSchema {
    pub name: String,
    pub variants: Vec<EnumVariant>,
    pub discriminant_type: String,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.EnumVariant")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnumVariant {
    pub name: String,
    pub value: i64,
    pub has_payload: bool,
    pub payload_type: Option<String>,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.TypeMapping")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeMapping {
    pub elixir_type: String,
    pub rust_type: String,
    pub serde_format: String,
    pub conversion_hint: Option<String>,
}

#[cfg_attr(feature = "nif", derive(NifStruct))]
#[cfg_attr(feature = "nif", module = "Lux.Native.SerializedValue")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SerializedValue {
    pub format: String,
    pub data: String,
    pub type_hint: Option<String>,
}

pub fn elixir_to_rust_type(elixir_type: &str) -> &str {
    match elixir_type {
        "atom" | "true" | "false" => "bool",
        "integer" => "i64",
        "float" => "f64",
        "binary" | "string" => "String",
        "list" => "Vec<Term>",
        "map" => "HashMap<String, Term>",
        "tuple" => "(Term, ...)",
        "pid" => "Pid",
        "nil" => "Option<T>",
        _ => "Term",
    }
}

pub fn rust_to_elixir_type(rust_type: &str) -> &str {
    match rust_type {
        "bool" => "boolean",
        "i8" | "i16" | "i32" | "i64" | "isize" => "integer",
        "u8" | "u16" | "u32" | "u64" | "usize" => "integer",
        "f32" | "f64" => "float",
        "String" | "&str" | "str" => "string",
        "Vec<Term>" | "&[Term]" => "list",
        "HashMap<String, Term>" => "map",
        _ => "term",
    }
}

pub fn standard_mappings() -> Vec<TypeMapping> {
    vec![
        TypeMapping {
            elixir_type: "integer".into(),
            rust_type: "i64".into(),
            serde_format: "integer".into(),
            conversion_hint: Some("Fits into i64 range unless very large".into()),
        },
        TypeMapping {
            elixir_type: "float".into(),
            rust_type: "f64".into(),
            serde_format: "float".into(),
            conversion_hint: Some("64-bit IEEE 754 float".into()),
        },
        TypeMapping {
            elixir_type: "binary".into(),
            rust_type: "String".into(),
            serde_format: "string".into(),
            conversion_hint: None,
        },
        TypeMapping {
            elixir_type: "boolean".into(),
            rust_type: "bool".into(),
            serde_format: "boolean".into(),
            conversion_hint: None,
        },
        TypeMapping {
            elixir_type: "atom".into(),
            rust_type: "String".into(),
            serde_format: "string".into(),
            conversion_hint: Some("Atoms serialized as their string name".into()),
        },
        TypeMapping {
            elixir_type: "list".into(),
            rust_type: "Vec<Term>".into(),
            serde_format: "array".into(),
            conversion_hint: Some("Lists convert to Vec; preserve order".into()),
        },
        TypeMapping {
            elixir_type: "map".into(),
            rust_type: "HashMap<String, Term>".into(),
            serde_format: "object".into(),
            conversion_hint: Some("String-keyed maps preferred".into()),
        },
        TypeMapping {
            elixir_type: "nil".into(),
            rust_type: "Option<T>".into(),
            serde_format: "null".into(),
            conversion_hint: Some("Nil maps to None in Option types".into()),
        },
        TypeMapping {
            elixir_type: "tuple".into(),
            rust_type: "(Term, ...)".into(),
            serde_format: "array".into(),
            conversion_hint: Some("Tuples serialize as fixed-size arrays".into()),
        },
    ]
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_elixir_to_rust_type_mapping() {
        assert_eq!(elixir_to_rust_type("integer"), "i64");
        assert_eq!(elixir_to_rust_type("float"), "f64");
        assert_eq!(elixir_to_rust_type("binary"), "String");
        assert_eq!(elixir_to_rust_type("nil"), "Option<T>");
    }

    #[test]
    fn test_rust_to_elixir_type_mapping() {
        assert_eq!(rust_to_elixir_type("i64"), "integer");
        assert_eq!(rust_to_elixir_type("f64"), "float");
        assert_eq!(rust_to_elixir_type("String"), "string");
    }

    #[test]
    fn test_standard_mappings_count() {
        let mappings = standard_mappings();
        assert_eq!(mappings.len(), 9);
    }

    #[test]
    fn test_lux_value_constructors() {
        let s = LuxValue::new_string("hello");
        assert!(s.is_string());
        assert!(!s.is_number());
        assert_eq!(s.data, "hello");

        let n = LuxValue::new_number(3.14);
        assert!(n.is_number());
        assert!(!n.is_string());
        assert_eq!(n.to_float(), Some(3.14));
    }

    #[test]
    fn test_lux_map_operations() {
        let mut map = LuxMap::new();
        assert_eq!(map.size, 0);

        map.insert("key1".into(), "val1".into());
        assert_eq!(map.size, 1);
        assert!(map.has_key("key1"));
        assert_eq!(map.get("key1"), Some(&"val1".to_string()));
    }

    #[test]
    fn test_lux_list_operations() {
        let mut list = LuxList::new();
        assert!(list.is_empty());

        list.push("a".into());
        list.push("b".into());
        assert_eq!(list.len(), 2);
        assert!(list.contains("a"));
        assert_eq!(list.first(), Some(&"a".to_string()));
    }

    #[test]
    fn test_type_mapping_serialization() {
        let mapping = TypeMapping {
            elixir_type: "integer".into(),
            rust_type: "i64".into(),
            serde_format: "integer".into(),
            conversion_hint: None,
        };
        let json = serde_json::to_string(&mapping).unwrap();
        let deserialized: TypeMapping = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.elixir_type, "integer");
    }

    #[test]
    fn test_enum_schema_validation() {
        let schema = EnumSchema {
            name: "Status".into(),
            variants: vec![
                EnumVariant {
                    name: "Active".into(),
                    value: 0,
                    has_payload: false,
                    payload_type: None,
                },
                EnumVariant {
                    name: "Inactive".into(),
                    value: 1,
                    has_payload: true,
                    payload_type: Some("String".into()),
                },
            ],
            discriminant_type: "i64".into(),
        };
        assert_eq!(schema.variants.len(), 2);
        assert_eq!(schema.variants[0].name, "Active");
        assert!(schema.variants[1].has_payload);
    }
}
