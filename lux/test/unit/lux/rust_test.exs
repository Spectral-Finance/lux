defmodule Lux.RustTest do
  use UnitAPICase, async: false

  alias Lux.Rust
  alias Lux.Prism

  setup do
    # Create temporary Cargo.toml file for testing package management
    temp_toml = "priv/rust/lux_nif/Cargo.toml.test"
    File.write!(temp_toml, """
    [package]
    name = "test_pkg"
    version = "0.1.0"
    edition = "2021"

    [dependencies]
    """)

    # Create temporary Rust component file
    temp_rs = "priv/rust/test_component.rs"
    File.write!(temp_rs, """
    // name: "Test Rust Component"
    // description: "A simple component written in Rust"
    fn main() {
        println!("hello from rust component");
    }
    """)

    on_exit(fn ->
      File.rm(temp_toml)
      File.rm(temp_rs)
      File.rm_rf("priv/rust/cache_test")
    end)

    {:ok, temp_toml: temp_toml, temp_rs: temp_rs}
  end

  describe "nif basic calls" do
    test "add/2 performs basic integer addition in Rust" do
      assert 30 == Rust.add(10, 20)
    end
  end

  describe "type mapping and serialization (Issue #101)" do
    test "serialize/1 maps Elixir map/list/primitive to JSON string" do
      data = %{"name" => "Lux", "versions" => [1, 2, 3]}
      serialized = Rust.serialize(data)
      assert is_binary(serialized)
      assert {:ok, decoded} = Jason.decode(serialized)
      assert %{"name" => "Lux", "versions" => [1, 2, 3]} == decoded
    end

    test "deserialize/1 maps JSON string to Elixir maps/lists" do
      json_str = ~s({"framework": "Lux", "tags": ["AI", "Agents"]})
      assert {:ok, term} = Rust.deserialize(json_str)
      assert %{"framework" => "Lux", "tags" => ["AI", "Agents"]} == term
    end

    test "echo_component/1 maps Custom Rust struct bidirectional mapping (Issue #101 / #103)" do
      comp = %{name: "My Rust Component", description: "Does rust things", version: "1.0", dependencies: ["serde"]}
      assert %{name: "My Rust Component", description: "Does rust things", version: "1.0", dependencies: ["serde"]} = Rust.echo_component(comp)
    end
  end

  describe "cargo package management (Issue #100)" do
    test "parse_toml/1 parses Cargo.toml file content" do
      toml_content = """
      [package]
      name = "my_custom_package"
      version = "1.2.3"

      [dependencies]
      tokio = "1.0"
      """
      assert {:ok, parsed} = Rust.parse_toml(toml_content)
      assert %{"package" => %{"name" => "my_custom_package", "version" => "1.2.3"}} = parsed
      assert %{"dependencies" => %{"tokio" => "1.0"}} = parsed
    end

    test "add_dependency/3 updates dependency list and returns updated TOML content", %{temp_toml: temp_toml} do
      assert {:ok, toml_str} = Rust.add_dependency(temp_toml, "serde", "1.0")
      assert toml_str =~ "serde = \"1.0\""
      assert toml_str =~ "name = \"test_pkg\""
    end

    test "cache_package/3 caches Rust dependency crate locally" do
      assert {:ok, path} = Rust.cache_package("serde", "1.0", "priv/rust/cache_test")
      assert File.exists?(path)
      assert File.read!(path) =~ "serde@1.0"
    end
  end

  describe "component definition & async/await execution (Issue #103)" do
    test "run_async/1 runs tasks using the async Tokio runtime" do
      assert {:ok, result} = Rust.run_async("hello tokio")
      assert result =~ "async result for: hello tokio"
    end

    test "Prism.view/2 parses Rust component files with comment headers", %{temp_rs: temp_rs} do
      prism = Prism.view(temp_rs)
      assert %Prism{name: "Test Rust Component", description: "A simple component written in Rust", handler: {:rust, ^temp_rs}} = prism
    end

    test "Prism.run/3 executes Rust component via FFI", %{temp_rs: temp_rs} do
      assert {:ok, %{result: result}} = Prism.run(temp_rs, "my input", %{})
      assert result =~ "async result for: path: #{temp_rs}"
    end
  end
end
