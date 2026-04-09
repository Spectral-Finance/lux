defmodule Lux.RustIntegrationTest do
  use ExUnit.Case, async: true

  alias Lux.Prism
  import Lux.Rust

  test "can list rust components" do
    components = Lux.Rust.list_components()
    assert "Echo" in components
    assert "Math" in components
  end

  test "can get component info" do
    info = Lux.Native.get_component_info("Math")
    assert info.name == "Math"
    assert info.description == "Perform math operations"
    assert String.contains?(info.input_schema, "op")
  end

  test "can call rust component via Lux.Rust" do
    assert {:ok, "hello"} == Lux.Rust.call("Echo", "hello")
    
    input = %{"op" => "add", "a" => 10, "b" => 20}
    assert {:ok, 30} == Lux.Rust.call("Math", input)
  end

  test "can use ~R sigil" do
    assert {:rust, "Math"} == ~R"Math"
  end

  test "can run a Prism with a rust handler" do
    prism = Prism.new(
      name: "Rust Math",
      handler: {:rust, "Math"}
    )

    input = %{"op" => "multiply", "a" => 5, "b" => 6}
    assert {:ok, 30} == Prism.run(prism, input)
  end

  test "returns error for missing component" do
    assert {:error, "Component 'Missing' not found"} == Lux.Rust.call("Missing", %{})
  end
end
