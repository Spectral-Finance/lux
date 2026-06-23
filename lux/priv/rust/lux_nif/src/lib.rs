#[derive(rustler::NifMap)]
struct LuxComponent {
    name: String,
    description: String,
    version: String,
    dependencies: Vec<String>,
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn echo_component(comp: LuxComponent) -> LuxComponent {
    comp
}

#[rustler::nif]
fn parse_toml_to_json(toml_str: String) -> Result<String, String> {
    let value: serde_json::Value = toml::from_str(&toml_str).map_err(|e| e.to_string())?;
    Ok(serde_json::to_string(&value).unwrap())
}

#[rustler::nif]
fn generate_toml(package_name: String, dependencies: Vec<(String, String)>) -> String {
    let mut toml_content = format!(
        "[package]\nname = \"{}\"\nversion = \"0.1.0\"\nedition = \"2021\"\n\n[dependencies]\n",
        package_name
    );
    for (name, ver) in dependencies {
        toml_content.push_str(&format!("{} = \"{}\"\n", name, ver));
    }
    toml_content
}

#[rustler::nif]
fn run_async_task(input: String) -> String {
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    rt.block_on(async {
        tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
        format!("async result for: {}", input)
    })
}

rustler::init!(
    "Elixir.Lux.Rust.NIF",
    [
        add,
        echo_component,
        parse_toml_to_json,
        generate_toml,
        run_async_task
    ]
);
