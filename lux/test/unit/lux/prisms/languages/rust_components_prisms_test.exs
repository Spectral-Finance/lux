defmodule Lux.Prisms.Languages.RustComponentsPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Languages.Rust.Components.RegistryPrism
  alias Lux.Prisms.Languages.Rust.Components.InvokePrism
  alias Lux.Prisms.Languages.Rust.Components.LifecyclePrism
  alias Lux.Prisms.Languages.Rust.Components.AsyncRunnerPrism
  alias Lux.Prisms.Languages.Rust.Components.SchemaSyncPrism

  describe "RegistryPrism" do
    test "lists all components without filter" do
      {:ok, result} = RegistryPrism.handler(%{}, %{})
      assert result.status == "ok"
      assert result.components_count >= 2
      assert is_list(result.components)
    end

    test "filters components by substring" do
      {:ok, result} = RegistryPrism.handler(%{"filter" => "hasher"}, %{})
      assert result.components_count == 1
      assert hd(result.components).name == "RustFastHasher"
    end
  end

  describe "SchemaSyncPrism" do
    test "validates schema for registered component" do
      {:ok, result} = SchemaSyncPrism.handler(%{"component_name" => "RustFastHasher"}, %{})
      assert result.is_synced == true
      assert result.component_name == "RustFastHasher"
      assert is_map(result.input_schema)
      assert is_map(result.output_schema)
    end

    test "returns is_synced false for unregistered component" do
      {:ok, result} = SchemaSyncPrism.handler(%{"component_name" => "Unknown"}, %{})
      assert result.is_synced == false
      assert result.component_name == "Unknown"
    end
  end

  describe "LifecyclePrism" do
    test "handles init lifecycle event" do
      {:ok, result} = LifecyclePrism.handler(%{"action" => "init", "component_name" => "RustFastHasher"}, %{})
      assert result.action == "init"
      assert result.component_name == "RustFastHasher"
      assert result.status == "ready"
    end

    test "handles teardown lifecycle event" do
      {:ok, result} = LifecyclePrism.handler(%{"action" => "teardown", "component_name" => "RustFastHasher"}, %{})
      assert result.action == "teardown"
      assert result.status == "terminated"
    end

    test "handles health check" do
      {:ok, result} = LifecyclePrism.handler(%{"action" => "health", "component_name" => "RustFastHasher"}, %{})
      assert result.action == "health"
      assert result.status == "healthy"
    end
  end

  describe "InvokePrism" do
    test "successfully invokes native component" do
      {:ok, result} =
        InvokePrism.handler(
          %{
            "component_name" => "RustFastHasher",
            "args" => %{"data" => "test payload"},
            "context" => %{}
          },
          %{}
        )

      assert result.success == true
      assert result.component_name == "RustFastHasher"
      assert is_map(result.result)
      assert Map.has_key?(result.result, "hash")
    end
  end

  describe "AsyncRunnerPrism" do
    test "asynchronously invokes component with timeout tracking" do
      {:ok, result} =
        AsyncRunnerPrism.handler(
          %{
            "component_name" => "RustFastHasher",
            "args" => %{"data" => "async payload"},
            "timeout_ms" => 3000
          },
          %{}
        )

      assert result.success == true
      assert is_number(result.duration_ms)
      assert is_map(result.result)
      assert Map.has_key?(result.result, "hash")
    end
  end
end
