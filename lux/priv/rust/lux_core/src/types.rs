use rustler::{NifMap, NifStruct};

/// A basic struct to demonstrate typed conversion from Elixir maps/structs
#[derive(NifMap, Debug, Clone)]
pub struct ExamplePayload {
    pub id: i64,
    pub data: String,
    pub is_active: bool,
}

/// A custom struct mapped to an Elixir struct %Lux.Native.ComplexData{}
#[derive(NifStruct)]
#[module = "Lux.Native.ComplexData"]
pub struct ComplexData {
    pub name: String,
    pub items: Vec<String>,
    pub metadata: ExamplePayload,
}
