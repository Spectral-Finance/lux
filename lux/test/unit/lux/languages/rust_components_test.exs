defmodule Lux.Languages.RustComponentsTest do
  use UnitCase, async: true

  alias Lux.Rust.Components.Registry
  alias Lux.Rust.Components.NativePrism

  describe "Registry.list_components/0" do
    test "lists registered native Rust components" do
      components = Registry.list_components()
      assert is_list(components)
      assert length(components) >= 2

      names = Enum.map(components, & &1.name)
      assert "RustMatrixMultiply" in names
      assert "RustFastHasher" in names
    end
  end

  describe "Registry.get_component/1" do
    test "fetches component metadata by name" do
      assert {:ok, comp} = Registry.get_component("RustMatrixMultiply")
      assert comp.name == "RustMatrixMultiply"
      assert comp.type == :prism
      assert is_map(comp.input_schema)
      assert is_map(comp.output_schema)
    end

    test "returns error for non-existent component" do
      assert {:error, :not_found} = Registry.get_component("NonExistentPrism")
    end
  end

  describe "Registry.invoke/4" do
    test "invokes RustFastHasher successfully" do
      payload = %{"data" => "hello lux"}
      assert {:ok, %{"hash" => hash}} = Registry.invoke("RustFastHasher", payload)
      assert is_binary(hash)
      assert String.length(hash) == 64
    end

    test "returns error on invalid arguments" do
      assert {:error, _reason} = Registry.invoke("RustFastHasher", %{})
    end
  end

  defmodule TestNativeHasherPrism do
    use NativePrism, rust_component: "RustFastHasher"
  end

  describe "NativePrism macro" do
    test "defines a valid prism delegating to Rust component" do
      assert TestNativeHasherPrism.name() == "RustFastHasher"
      assert {:ok, result} = TestNativeHasherPrism.handler(%{"data" => "test"}, %{})
      assert is_map(result)
      assert Map.has_key?(result, "hash")
    end
  end
end
