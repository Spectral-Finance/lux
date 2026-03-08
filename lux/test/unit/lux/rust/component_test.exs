defmodule Lux.Rust.ComponentTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  defmodule TestPrism do
    use Lux.Rust.Component,
      type: :prism,
      name: "Test Prism",
      description: "A test prism"

    @impl true
    def handle(params, _context) do
      input = params["input"] || params[:input] || ""
      {:ok, %{result: Lux.Native.sha256_hex(input)}}
    end
  end

  defmodule TestBeam do
    use Lux.Rust.Component,
      type: :beam,
      name: "Test Beam",
      description: "A test beam"

    @impl true
    def handle(params, _context) do
      data = params["data"] || params[:data] || "null"
      case Lux.Native.validate_json(data, "object") do
        {:ok, _} -> {:ok, %{valid: true}}
        {:error, reason} -> {:ok, %{valid: false, error: reason}}
      end
    end

    @impl true
    def init(_opts), do: :ok
  end

  describe "component definition" do
    test "prism has correct metadata" do
      assert TestPrism.__component_type__() == :prism
      assert TestPrism.__component_name__() == "Test Prism"
      assert TestPrism.__component_description__() == "A test prism"
    end

    test "beam has correct metadata" do
      assert TestBeam.__component_type__() == :beam
      assert TestBeam.__component_name__() == "Test Beam"
    end
  end

  describe "handle/2" do
    test "prism processes input through NIF" do
      assert {:ok, %{result: hash}} = TestPrism.handle(%{input: "hello"}, %{})
      assert hash == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end

    test "beam validates JSON" do
      assert {:ok, %{valid: true}} = TestBeam.handle(%{data: ~s({"a":1})}, %{})
      assert {:ok, %{valid: false}} = TestBeam.handle(%{data: "42"}, %{})
    end
  end

  describe "lifecycle" do
    test "init returns :ok by default" do
      assert TestPrism.init([]) == :ok
    end

    test "terminate returns :ok by default" do
      assert TestPrism.terminate(:normal) == :ok
    end

    test "custom init" do
      assert TestBeam.init([]) == :ok
    end
  end
end
