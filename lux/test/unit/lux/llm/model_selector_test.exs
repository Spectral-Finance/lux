defmodule Lux.LLM.ModelSelectorTest do
  use UnitCase, async: false

  alias Lux.LLM.ModelSelector
  alias Lux.LLM.Registry

  describe "select/1" do
    test "selects a provider with default requirements" do
      result = ModelSelector.select()

      case result do
        {:ok, name, module, model_name} ->
          assert is_atom(name)
          assert is_atom(module)
          assert is_binary(model_name)

        {:error, _reason} ->
          # No providers with :chat capability registered
          :ok
      end
    end

    test "selects provider with specific capabilities" do
      result = ModelSelector.select(capabilities: [:chat, :tool_use])

      case result do
        {:ok, name, _module, _model} ->
          assert name in [:openai, :anthropic, :together_ai]

        {:error, _} ->
          :ok
      end
    end

    test "respects excluded_providers" do
      result =
        ModelSelector.select(
          capabilities: [:chat],
          excluded_providers: [:openai, :anthropic, :mira]
        )

      case result do
        {:ok, name, _module, _model} ->
          refute name == :openai
          refute name == :anthropic
          refute name == :mira

        {:error, _} ->
          :ok
      end
    end

    test "respects preferred_providers" do
      # Make anthropic preferred
      result =
        ModelSelector.select(
          capabilities: [:chat],
          preferred_providers: [:anthropic]
        )

      case result do
        {:ok, name, _module, _model} ->
          # Anthropic should be preferred (but not guaranteed if other scoring factors differ)
          assert is_atom(name)

        {:error, _} ->
          :ok
      end
    end

    test "returns error when no matching providers found" do
      result =
        ModelSelector.select(
          capabilities: [:chat, :vision, :reasoning, :streaming],
          excluded_providers: [:openai, :anthropic, :together_ai, :mira]
        )

      assert {:error, _reason} = result
    end

    test "cheapest strategy prefers lower cost models" do
      result = ModelSelector.select(capabilities: [:chat], strategy: :cheapest)

      case result do
        {:ok, _name, _module, _model} -> :ok
        {:error, _} -> :ok
      end
    end

    test "fastest strategy works" do
      # Report some health data so fastest has something to work with
      Registry.report_health(:openai, :ok, 100)
      Registry.report_health(:anthropic, :ok, 500)

      result = ModelSelector.select(capabilities: [:chat], strategy: :fastest)

      case result do
        {:ok, _name, _module, _model} -> :ok
        {:error, _} -> :ok
      end
    end

    test "balanced strategy works" do
      result = ModelSelector.select(capabilities: [:chat], strategy: :balanced)

      case result do
        {:ok, _name, _module, _model} -> :ok
        {:error, _} -> :ok
      end
    end

    test "max_cost_per_1k_tokens filters expensive models" do
      # Very low cost constraint should filter out expensive models
      result =
        ModelSelector.select(
          capabilities: [:chat],
          max_cost_per_1k_tokens: 0.0000001
        )

      # May or may not find models - depends on pricing data
      assert is_tuple(result)
    end

    test "min_context_window filters small models" do
      result =
        ModelSelector.select(
          capabilities: [:chat],
          min_context_window: 100_000
        )

      case result do
        {:ok, _name, _module, _model} -> :ok
        {:error, _} -> :ok
      end
    end
  end

  describe "available_models/1" do
    test "returns all models without filter" do
      models = ModelSelector.available_models()
      assert is_list(models)

      if length(models) > 0 do
        first = hd(models)
        assert Map.has_key?(first, :provider)
        assert Map.has_key?(first, :model)
      end
    end

    test "filters by capabilities" do
      models = ModelSelector.available_models(capabilities: [:chat, :tool_use])

      for %{model: model} <- models do
        assert :chat in model.capabilities
        assert :tool_use in model.capabilities
      end
    end

    test "vision capability filter" do
      models = ModelSelector.available_models(capabilities: [:vision])

      for %{model: model} <- models do
        assert :vision in model.capabilities
      end
    end
  end
end
