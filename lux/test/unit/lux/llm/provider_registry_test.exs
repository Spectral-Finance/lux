defmodule Lux.LLM.ProviderRegistryTest do
  use UnitCase, async: true

  alias Lux.LLM.Provider
  alias Lux.LLM.ProviderRegistry

  describe "select/2" do
    test "selects the default balanced provider" do
      assert {:ok, selection} =
               ProviderRegistry.select(ProviderRegistry.default_registry(), %{
                 capabilities: [:chat, :tools],
                 input_tokens: 1_000,
                 output_tokens: 500
               })

      assert selection.provider.id == :open_ai
      assert selection.model == "gpt-4o-mini"
      assert is_number(selection.estimated_cost)
      assert {:anthropic, "claude-3-haiku-20240307"} in selection.fallback_chain
    end

    test "can optimize for quality" do
      assert {:ok, selection} =
               ProviderRegistry.select(ProviderRegistry.default_registry(), %{
                 capabilities: [:chat, :tools],
                 strategy: :quality
               })

      assert selection.model == "gpt-4o"
    end

    test "filters providers by capability" do
      assert {:ok, selection} =
               ProviderRegistry.select(ProviderRegistry.default_registry(), %{
                 capabilities: [:vision]
               })

      assert selection.provider.id == :open_ai
      assert selection.model == "gpt-4o"
    end

    test "honors forced provider and model" do
      assert {:ok, selection} =
               ProviderRegistry.select(ProviderRegistry.default_registry(), %{
                 provider: "anthropic",
                 model: "claude-3-haiku-20240307",
                 capabilities: ["chat"]
               })

      assert selection.provider.id == :anthropic
      assert selection.model == "claude-3-haiku-20240307"
    end

    test "returns an error when no provider matches" do
      assert {:error, :no_provider_available} =
               ProviderRegistry.select(ProviderRegistry.default_registry(), %{
                 capabilities: [:image_generation]
               })
    end

    test "supports custom providers" do
      custom =
        Provider.new(%{
          id: :local,
          module: Lux.LLM.OpenAI,
          default_model: "llama-local",
          priority: 1,
          capabilities: [:chat],
          models: %{
            "llama-local" => %{
              capabilities: [:chat],
              input_cost_per_1k: 0,
              output_cost_per_1k: 0,
              quality: 0.5,
              latency_ms: 100
            }
          }
        })

      registry =
        ProviderRegistry.default_registry()
        |> ProviderRegistry.register(custom)

      assert {:ok, selection} = ProviderRegistry.select(registry, %{capabilities: [:chat]})
      assert selection.provider.id == :local
    end
  end

  describe "usage_summary/1" do
    test "aggregates usage by provider/model" do
      summary =
        ProviderRegistry.usage_summary([
          %{provider: :open_ai, model: "gpt-4o-mini", input_tokens: 100, output_tokens: 50, cost: 0.01},
          %{provider: "open_ai", model: "gpt-4o-mini", input_tokens: 200, output_tokens: 150, cost: 0.02}
        ])

      assert summary.total_input_tokens == 300
      assert summary.total_output_tokens == 200
      assert summary.total_cost == 0.03
      assert summary.by_model[{:open_ai, "gpt-4o-mini"}].requests == 2
    end
  end

  describe "cache_key/1" do
    test "creates stable keys for equivalent requests" do
      key_a = ProviderRegistry.cache_key(%{capabilities: [:chat, :tools], strategy: :cost})
      key_b = ProviderRegistry.cache_key(%{"capabilities" => ["chat", "tools"], "strategy" => "cost"})

      assert key_a == key_b
      assert byte_size(key_a) == 64
    end
  end
end
