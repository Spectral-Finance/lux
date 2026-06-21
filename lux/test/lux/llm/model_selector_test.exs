defmodule Lux.LLM.ModelSelectorTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.ModelSelector

  @models [
    %{id: "gpt-4", cost_per_input_token: 0.03, capabilities: [:chat, :function_calling, :vision]},
    %{id: "gpt-3.5-turbo", cost_per_input_token: 0.001, capabilities: [:chat, :function_calling]},
    %{id: "claude-3-haiku", cost_per_input_token: 0.00025, capabilities: [:chat]},
    %{id: "gpt-4-vision", cost_per_input_token: 0.04, capabilities: [:chat, :vision]}
  ]

  describe "select/2" do
    test "returns cheapest model with required capabilities" do
      assert {:ok, model} = ModelSelector.select(@models, required_capabilities: [:chat])
      assert model.id == "claude-3-haiku"
    end

    test "filters by multiple capabilities" do
      assert {:ok, model} = ModelSelector.select(@models, required_capabilities: [:chat, :vision])
      # gpt-4 (0.03) is cheaper than gpt-4-vision (0.04)
      assert model.id == "gpt-4"
    end

    test "returns error when no model matches capabilities" do
      assert {:error, :no_suitable_model} =
               ModelSelector.select(@models, required_capabilities: [:embedding])
    end

    test "returns error for empty model list" do
      assert {:error, :no_suitable_model} = ModelSelector.select([])
    end

    test "filters by max_cost_per_token" do
      assert {:ok, model} =
               ModelSelector.select(@models,
                 required_capabilities: [:chat],
                 max_cost_per_token: 0.001
               )

      assert model.cost_per_input_token <= 0.001
    end

    test "returns error when all models exceed cost limit" do
      assert {:error, :no_suitable_model} =
               ModelSelector.select(@models,
                 required_capabilities: [:chat],
                 max_cost_per_token: 0.00001
               )
    end

    test "defaults to no capability filter, returns cheapest" do
      assert {:ok, model} = ModelSelector.select(@models)
      assert model.id == "claude-3-haiku"
    end
  end

  describe "select_all/2" do
    test "returns all matching models sorted by cost" do
      results = ModelSelector.select_all(@models, required_capabilities: [:chat, :function_calling])
      assert length(results) == 2
      costs = Enum.map(results, & &1.cost_per_input_token)
      assert costs == Enum.sort(costs)
    end

    test "returns empty list when nothing matches" do
      assert [] = ModelSelector.select_all(@models, required_capabilities: [:unknown_cap])
    end
  end
end
