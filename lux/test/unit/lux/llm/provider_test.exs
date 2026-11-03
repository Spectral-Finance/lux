defmodule Lux.LLM.ProviderTest do
  use ExUnit.Case, async: false

  alias Lux.LLM
  alias Lux.LLM.Provider
  alias Lux.LLM.Provider.Spec

  defmodule MockFailingProvider do
    @behaviour Lux.LLM

    @impl true
    def call(_prompt, _tools, _opts) do
      {:error, :rate_limited}
    end
  end

  defmodule MockSuccessProvider do
    @behaviour Lux.LLM

    @impl true
    def call(prompt, _tools, opts) do
      model = Map.get(opts, :model, "mock-default")
      {:ok, %{content: "Echo from #{model}: #{prompt}", finish_reason: "stop"}}
    end
  end

  setup do
    Provider.ensure_started()
    Provider.reset_metrics()
    Provider.clear_cache()
    :ok
  end

  describe "provider registry" do
    test "lists default providers (OpenAI, Anthropic, TogetherAI, Mira)" do
      providers = LLM.list_providers()
      ids = Enum.map(providers, & &1.id)

      assert :openai in ids
      assert :anthropic in ids
      assert :together_ai in ids
      assert :mira in ids
    end

    test "registers and retrieves a custom provider specification" do
      {:ok, spec} =
        LLM.register_provider(:custom_mock, %Spec{
          module: MockSuccessProvider,
          default_model: "mock-v1",
          cost_per_1k_input: 0.0001,
          cost_per_1k_output: 0.0002,
          avg_latency_ms: 120,
          capabilities: [:chat, :fast_inference],
          priority: 110
        })

      assert spec.id == :custom_mock
      assert {:ok, fetched} = LLM.get_provider(:custom_mock)
      assert fetched.default_model == "mock-v1"
    end
  end

  describe "automatic model and provider selection" do
    test "selects lowest cost provider under :cost_optimized strategy" do
      {:ok, spec} = LLM.select_provider(%{strategy: :cost_optimized})
      assert spec.id == :together_ai
    end

    test "selects highest priority provider under :quality strategy" do
      {:ok, spec} = LLM.select_provider(%{strategy: :quality})
      assert spec.id == :openai
    end

    test "filters providers by required capabilities and max cost" do
      {:ok, spec} =
        LLM.select_provider(%{
          required_capabilities: [:long_context],
          strategy: :quality
        })

      assert spec.id == :anthropic
    end
  end

  describe "intelligent fallback, caching, and telemetry" do
    test "automatically falls back to secondary provider when primary fails" do
      LLM.register_provider(:mock_fail, %Spec{
        module: MockFailingProvider,
        default_model: "fail-model",
        priority: 200
      })

      LLM.register_provider(:mock_ok, %Spec{
        module: MockSuccessProvider,
        default_model: "ok-model",
        cost_per_1k_input: 0.001,
        cost_per_1k_output: 0.002,
        priority: 190
      })

      assert {:ok, response} =
               LLM.call_with_fallback("Analyze DeFi liquidity", [], %{
                 fallback_providers: [:mock_fail, :mock_ok],
                 cache: true
               })

      assert response.content == "Echo from ok-model: Analyze DeFi liquidity"

      metrics = LLM.get_metrics()
      assert metrics.providers[:mock_fail].failures == 1
      assert metrics.providers[:mock_ok].successes == 1
      assert metrics.total_cost_usd >= 0.0

      # Second identical call hits ETS cache
      assert {:ok, cached_response} =
               LLM.call_with_fallback("Analyze DeFi liquidity", [], %{
                 fallback_providers: [:mock_fail, :mock_ok],
                 cache: true
               })

      assert cached_response == response
      assert LLM.get_metrics().cache_hits == 1
    end
  end
end
