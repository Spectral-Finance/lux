defmodule Lux.LLM.ModelSelectorTest do
  use UnitCase, async: true

  alias Lux.LLM.ModelSelector

  describe "select_model/1" do
    test "selects cost optimized model" do
      assert {:ok, model} = ModelSelector.select_model(%{strategy: :cost_optimized})
      assert model.tier == :cost_optimized
      assert model.input_cost_per_m < 1.0
    end

    test "selects reasoning optimized model" do
      assert {:ok, model} = ModelSelector.select_model(%{strategy: :reasoning_optimized})
      assert model.tier == :reasoning_optimized
      assert model.model in ["o1", "claude-3-5-sonnet-20241022"]
    end

    test "selects latency optimized model" do
      assert {:ok, model} = ModelSelector.select_model(%{strategy: :latency_optimized})
      assert model.avg_latency_ms <= 300
    end

    test "filters by capability" do
      assert {:ok, model} = ModelSelector.select_model(%{required_capabilities: [:prompt_caching]})
      assert :prompt_caching in model.capabilities
      assert model.provider == :anthropic
    end
  end

  describe "list_catalog/0" do
    test "returns full catalog list" do
      catalog = ModelSelector.list_catalog()
      assert length(catalog) >= 6
    end
  end
end
