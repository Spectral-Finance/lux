use rustler::{NifStruct, NifEnum};
use serde::{Deserialize, Serialize};

#[derive(NifEnum, Serialize, Deserialize, Debug, PartialEq)]
pub enum ComplexType {
    String,
    Integer,
    Boolean,
    Float,
    List,
    Map,
    Custom,
}

#[derive(NifStruct, Serialize, Deserialize, Debug, PartialEq)]
#[module = "Lux.TypeSystem.ComplexStruct"]
pub struct ComplexStruct {
    pub id: i64,
    pub name: String,
    pub type_def: ComplexType,
    pub metadata: String,
    pub is_active: bool,
}

#[rustler::nif]
pub fn serialize_to_json(struct_data: ComplexStruct) -> String {
    serde_json::to_string(&struct_data).unwrap_or_else(|_| "".to_string())
}

#[rustler::nif]
pub fn deserialize_from_json(json_str: String) -> Result<ComplexStruct, String> {
    serde_json::from_str(&json_str).map_err(|e| e.to_string())
}

#[rustler::nif]
pub fn process_complex_type(struct_data: ComplexStruct) -> ComplexStruct {
    let mut updated = struct_data;
    updated.is_active = !updated.is_active;
    updated.name = format!("{}_processed", updated.name);
    updated
}

rustler::init!("Elixir.Lux.TypeSystem", [serialize_to_json, deserialize_from_json, process_complex_type]);
