class CargoManager:
    def __init__(self):
        self.cargo_toml_content = """[package]
name = "lux"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
"""

    def generate_cargo_toml(self):
        return self.cargo_toml_content