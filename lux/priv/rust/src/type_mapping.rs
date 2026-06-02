use crate::types::{
    elixir_to_rust_type, rust_to_elixir_type, standard_mappings,
    FieldDescriptor, TypeSchema, EnumSchema, EnumVariant, TypeMapping,
};

pub fn map_elixir_to_rust_type(elixir_type: &str) -> String {
    elixir_to_rust_type(elixir_type).to_string()
}

pub fn map_rust_to_elixir_type(rust_type: &str) -> String {
    rust_to_elixir_type(rust_type).to_string()
}

pub fn get_standard_mappings() -> Vec<TypeMapping> {
    standard_mappings()
}

pub fn check_compatibility(elixir_type: &str, rust_type: &str) -> bool {
    let expected_rust = elixir_to_rust_type(elixir_type);
    expected_rust == rust_type || expected_rust == "Term"
}

pub fn validate_schema(schema_json: &str) -> Result<String, String> {
    let schema: TypeSchema = serde_json::from_str(schema_json)
        .map_err(|e| format!("schema_parse_error: {}", e))?;

    let mut errors: Vec<String> = Vec::new();

    if schema.kind.is_empty() {
        errors.push("kind must not be empty".into());
    }

    for field in &schema.fields {
        if field.name.is_empty() {
            errors.push("field name must not be empty".into());
        }
        if field.rust_type.is_empty() {
            errors.push(format!("field '{}' has empty rust_type", field.name));
        }
    }

    if errors.is_empty() {
        Ok(serde_json::to_string(&serde_json::json!({
            "valid": true,
            "warnings": []
        })).unwrap())
    } else {
        Ok(serde_json::to_string(&serde_json::json!({
            "valid": false,
            "errors": errors
        })).unwrap())
    }
}

pub fn define_struct(
    name: &str,
    kind: &str,
    fields_json: &str,
) -> Result<String, String> {
    let fields: Vec<FieldDescriptor> = serde_json::from_str(fields_json)
        .map_err(|e| format!("fields_parse_error: {}", e))?;

    let schema = TypeSchema {
        kind: kind.to_string(),
        fields,
        constraints: None,
    };

    let rust_def = generate_rust_struct(name, &schema);
    let schema_json = serde_json::to_string(&schema)
        .map_err(|e| format!("serialize_error: {}", e))?;

    Ok(serde_json::to_string(&serde_json::json!({
        "name": name,
        "schema": serde_json::from_str::<serde_json::Value>(&schema_json).unwrap(),
        "rust_definition": rust_def
    })).unwrap())
}

pub fn define_enum(
    name: &str,
    variants_json: &str,
    discriminant_type: &str,
) -> Result<String, String> {
    let variants: Vec<EnumVariant> = serde_json::from_str(variants_json)
        .map_err(|e| format!("variants_parse_error: {}", e))?;

    let schema = EnumSchema {
        name: name.to_string(),
        variants: variants.clone(),
        discriminant_type: discriminant_type.to_string(),
    };

    let rust_def = generate_rust_enum(name, &schema);
    let schema_json = serde_json::to_string(&schema)
        .map_err(|e| format!("serialize_error: {}", e))?;

    Ok(serde_json::to_string(&serde_json::json!({
        "name": name,
        "schema": serde_json::from_str::<serde_json::Value>(&schema_json).unwrap(),
        "rust_definition": rust_def
    })).unwrap())
}

fn generate_rust_struct(name: &str, schema: &TypeSchema) -> String {
    let mut lines: Vec<String> = Vec::new();
    lines.push("#[derive(Debug, Clone, Serialize, Deserialize)]".into());
    lines.push(format!("pub struct {} {{", name));

    for field in &schema.fields {
        if field.is_optional {
            lines.push(format!(
                "    pub {}: Option<{}>,",
                field.name, field.rust_type
            ));
        } else {
            lines.push(format!(
                "    pub {}: {},",
                field.name, field.rust_type
            ));
        }
    }

    lines.push("}".into());
    lines.join("\n")
}

fn generate_rust_enum(name: &str, schema: &EnumSchema) -> String {
    let mut lines: Vec<String> = Vec::new();
    lines.push("#[derive(Debug, Clone, Serialize, Deserialize)]".into());
    lines.push("#[serde(tag = \"type\", content = \"value\")]".into());
    lines.push(format!("pub enum {} {{", name));

    for variant in &schema.variants {
        if variant.has_payload {
            let payload = variant.payload_type.as_deref().unwrap_or("String");
            lines.push(format!("    {}({}),", variant.name, payload));
        } else {
            lines.push(format!("    {},", variant.name));
        }
    }

    lines.push("}".into());
    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_map_elixir_to_rust_type() {
        assert_eq!(map_elixir_to_rust_type("integer"), "i64");
        assert_eq!(map_elixir_to_rust_type("float"), "f64");
        assert_eq!(map_elixir_to_rust_type("binary"), "String");
    }

    #[test]
    fn test_map_rust_to_elixir_type() {
        assert_eq!(map_rust_to_elixir_type("i64"), "integer");
        assert_eq!(map_rust_to_elixir_type("f64"), "float");
        assert_eq!(map_rust_to_elixir_type("Vec<Term>"), "list");
    }

    #[test]
    fn test_check_compatibility() {
        assert!(check_compatibility("integer", "i64"));
        assert!(check_compatibility("binary", "String"));
        assert!(!check_compatibility("float", "String"));
    }

    #[test]
    fn test_get_standard_mappings() {
        let mappings = get_standard_mappings();
        assert_eq!(mappings.len(), 9);
        assert_eq!(mappings[0].elixir_type, "integer");
    }

    #[test]
    fn test_validate_schema_valid() {
        let schema = serde_json::json!({
            "kind": "struct",
            "fields": [
                {"name": "count", "rust_type": "i64", "is_optional": false, "default_value": null, "validators": []}
            ],
            "constraints": null
        });
        let result = validate_schema(&schema.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&result.unwrap()).unwrap();
        assert_eq!(parsed["valid"], true);
    }

    #[test]
    fn test_validate_schema_invalid() {
        let schema = serde_json::json!({
            "kind": "",
            "fields": [
                {"name": "", "rust_type": "", "is_optional": false, "default_value": null, "validators": []}
            ],
            "constraints": null
        });
        let result = validate_schema(&schema.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&result.unwrap()).unwrap();
        assert_eq!(parsed["valid"], false);
    }

    #[test]
    fn test_define_struct() {
        let result = define_struct(
            "MyStruct",
            "struct",
            &serde_json::json!([
                {"name": "id", "rust_type": "u64", "is_optional": false, "default_value": null, "validators": []},
                {"name": "label", "rust_type": "String", "is_optional": true, "default_value": null, "validators": []}
            ]).to_string(),
        );
        let parsed: serde_json::Value = serde_json::from_str(&result.unwrap()).unwrap();
        assert_eq!(parsed["name"], "MyStruct");
        assert!(parsed["rust_definition"].as_str().unwrap().contains("pub struct MyStruct"));
    }

    #[test]
    fn test_define_enum() {
        let result = define_enum(
            "Status",
            &serde_json::json!([
                {"name": "Active", "value": 0, "has_payload": false, "payload_type": null},
                {"name": "Error", "value": 1, "has_payload": true, "payload_type": "String"}
            ]).to_string(),
            "i64",
        );
        let parsed: serde_json::Value = serde_json::from_str(&result.unwrap()).unwrap();
        assert_eq!(parsed["name"], "Status");
        assert!(parsed["rust_definition"].as_str().unwrap().contains("pub enum Status"));
    }
}
