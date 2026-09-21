# Cargo package integration

class CargoIntegration:
    def __init__(self):
        self.toml_content = ""

    def generate_cargo_toml(self, package_name, version):
        self.toml_content = f"""[package]\nname = \"{package_name}\"\nversion = \"{version}\"\nedition = \"2021\"\n\n[dependencies]\n"""
        return self.toml_content

    def add_dependency(self, dependency):
        self.toml_content += f"{dependency}\n"

    def build(self):
        return "cargo build"

    def cache_packages(self):
        return True
