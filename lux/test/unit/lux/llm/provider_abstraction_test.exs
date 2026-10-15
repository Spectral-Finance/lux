defmodule Lux.LLM.ProviderAbstractionTest do
  use UnitAPICase, async: false

  alias Lux.LLM
  alias Lux.LLM.Anthropic
  alias Lux.LLM.Cache
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.OpenAI
  alias Lux.LLM.Provider
  alias Lux.LLM.Provider.ModelInfo
  alias Lux.LLM.Provider.Spec
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Response
  alias Lux.LLM.ResponseSignal
  alias Lux.LLM.Router
  alias Lux.LLM.Telemetry
  alias Lux.Signal

  defmodule FailingMockProvider do
    @moduledoc false
    @behaviour Lux.LLM

    @impl true
    def call(_prompt, _tools, _config) do
      {:error, :provider_unavailable}
    end
  end

  defmodule SucceedingMockProvider do
    @moduledoc false
    @behaviour Lux.LLM

    @impl true
    def call(prompt, _tools, config) do
      {:ok,
       %Response{
         content: "Handled by #{config[:model]}: #{prompt}",
         tool_calls: [],
         finish_reason: "stop",
         structured_output: nil
       }}
    end
  end

  setup do
    ProviderRegistry.reset!()
    Telemetry.reset!()
    Cache.clear!()
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Lux.LLM.Provider" do
    test "provides default provider specifications for built-in providers" do
      specs = Provider.default_provider_specs()
      ids = Enum.map(specs, & &1.id)

      assert :openai in ids
      assert :anthropic in ids
      assert :together_ai in ids
      assert :mira in ids
    end

    test "normalizes OpenAI ResponseSignal into Lux.LLM.Response" do
      signal =
        Signal.new(%{
          schema_id: ResponseSignal,
          payload: %{
            content: %{"answer" => "42"},
            model: "gpt-4o-mini",
            finish_reason: "stop",
            tool_calls: [
              %{
                "type" => "function",
                "function" => %{
                  "name" => "calc",
                  "arguments" => ~s({"x": 1})
                }
              }
            ],
            tool_calls_results: nil
          },
          metadata: %{
            usage: %{"prompt_tokens" => 12, "completion_tokens" => 8, "total_tokens" => 20}
          }
        })

      assert {:ok, %Response{} = normalized} = Provider.normalize_response({:ok, signal}, :openai)
      assert normalized.structured_output == %{"answer" => "42"}
      assert normalized.finish_reason == "stop"
      assert [%{name: "calc", params: %{"x" => 1}}] = normalized.tool_calls

      usage = Provider.extract_usage(signal)
      assert usage == %{prompt_tokens: 12, completion_tokens: 8, total_tokens: 20}
    end
  end

  describe "Lux.LLM.ProviderRegistry" do
    test "registers custom providers and manages circuit breaker health" do
      {:ok, spec} =
        ProviderRegistry.register_provider(:custom_llm, %Spec{
          id: :custom_llm,
          module: SucceedingMockProvider,
          default_model: "custom-v1",
          priority: 120,
          circuit_breaker_threshold: 2,
          circuit_breaker_cooldown_ms: 60_000,
          models: [
            %ModelInfo{
              name: "custom-v1",
              provider: :custom_llm,
              tier: :balanced,
              input_cost_per_1k: 0.0005,
              output_cost_per_1k: 0.001,
              avg_latency_ms: 250,
              quality_score: 0.90,
              capabilities: [:tools, :json_mode]
            }
          ]
        })

      assert spec.id == :custom_llm
      assert ProviderRegistry.healthy?(:custom_llm)

      ProviderRegistry.mark_failure(:custom_llm, :timeout)
      assert ProviderRegistry.healthy?(:custom_llm)

      ProviderRegistry.mark_failure(:custom_llm, :timeout)
      refute ProviderRegistry.healthy?(:custom_llm)

      ProviderRegistry.mark_success(:custom_llm)
      assert ProviderRegistry.healthy?(:custom_llm)

      ProviderRegistry.disable_provider(:custom_llm)
      refute ProviderRegistry.healthy?(:custom_llm)

      ProviderRegistry.enable_provider(:custom_llm)
      assert ProviderRegistry.healthy?(:custom_llm)
    end
  end

  describe "Lux.LLM.ModelSelector" do
    test "estimates task complexity from prompt and tools" do
      assert ModelSelector.estimate_complexity("Hello!", []) == :simple

      assert ModelSelector.estimate_complexity(
               "Please analyze step by step how this protocol works.",
               []
             ) == :moderate

      complex_prompt =
        "Please analyze and evaluate the architecture step by step: " <>
          String.duplicate("detailed specification data ", 40)

      assert ModelSelector.estimate_complexity(complex_prompt, []) == :complex
    end

    test "selects models according to optimization strategy" do
      {:ok, cheapest} =
        ModelSelector.select("Quick summary", [], %{strategy: :cost_optimized})

      assert cheapest.model_info.input_cost_per_1k <= 0.0003

      {:ok, smartest} =
        ModelSelector.select("Deep architectural reasoning", [], %{strategy: :quality_optimized})

      assert smartest.model_info.quality_score >= 0.95

      {:ok, fastest} =
        ModelSelector.select("Fast classification", [], %{strategy: :latency_optimized})

      assert fastest.model_info.avg_latency_ms <= 450
    end

    test "filters models by required capabilities and cost budget" do
      {:ok, selected} =
        ModelSelector.select("Analyze image and return JSON", [], %{
          required_capabilities: [:vision, :json_mode],
          max_cost_per_1k: 0.001
        })

      assert :vision in selected.model_info.capabilities
      assert :json_mode in selected.model_info.capabilities
      assert selected.provider == :openai
      assert selected.model == "gpt-4o-mini"
    end
  end

  describe "Lux.LLM.Router fallback, caching, and telemetry" do
    test "automatically falls back to secondary provider when primary fails" do
      ProviderRegistry.register_provider(:primary_fail, %{
        module: FailingMockProvider,
        default_model: "fail-model-1",
        priority: 200,
        models: [
          %{
            name: "fail-model-1",
            tier: :balanced,
            input_cost_per_1k: 0.001,
            output_cost_per_1k: 0.002,
            avg_latency_ms: 300,
            quality_score: 0.9,
            capabilities: [:tools]
          }
        ]
      })

      ProviderRegistry.register_provider(:secondary_ok, %{
        module: SucceedingMockProvider,
        default_model: "backup-model-1",
        priority: 150,
        models: [
          %{
            name: "backup-model-1",
            tier: :balanced,
            input_cost_per_1k: 0.001,
            output_cost_per_1k: 0.002,
            avg_latency_ms: 350,
            quality_score: 0.88,
            capabilities: [:tools]
          }
        ]
      })

      assert {:ok, %Response{content: "Handled by backup-model-1: test fallback"}} =
               LLM.call("test fallback", [], %{
                 provider: :primary_fail,
                 fallback_providers: [:secondary_ok],
                 normalize_response: true
               })

      metrics = LLM.metrics()
      assert metrics.global.total_requests == 2
      assert metrics.global.failed_requests == 1
      assert metrics.global.successful_requests == 1
      assert metrics.global.fallback_count == 1
      assert metrics.providers[:primary_fail].failed_requests == 1
      assert metrics.providers[:secondary_ok].successful_requests == 1
    end

    test "falls back from OpenAI HTTP failure to Anthropic HTTP success" do
      Req.Test.expect(OpenAI, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          500,
          Jason.encode!(%{"error" => %{"message" => "Internal server error"}})
        )
      end)

      Req.Test.expect(Anthropic, fn conn ->
        Req.Test.json(conn, %{
          "id" => "msg_fallback_1",
          "type" => "message",
          "role" => "assistant",
          "content" => [%{"type" => "text", "text" => "Anthropic fallback response"}],
          "model" => "claude-3-sonnet-20240229",
          "stop_reason" => "end_turn"
        })
      end)

      assert {:ok, %Response{content: "Anthropic fallback response"}} =
               Router.call("Hello with failover", [], %{
                 provider: :openai,
                 fallback_providers: [:anthropic],
                 api_key: "test_key",
                 normalize_response: true
               })
    end

    test "caches responses and records cache hits without duplicate provider calls" do
      ProviderRegistry.register_provider(:cached_mock, %{
        module: SucceedingMockProvider,
        default_model: "fast-v1",
        priority: 180,
        models: [
          %{
            name: "fast-v1",
            tier: :cheapest,
            input_cost_per_1k: 0.001,
            output_cost_per_1k: 0.002,
            avg_latency_ms: 200,
            quality_score: 0.85,
            capabilities: [:tools]
          }
        ]
      })

      opts = %{provider: :cached_mock, cache: true, cache_ttl_ms: 60_000}

      assert {:ok, %Response{content: "Handled by fast-v1: repeat query"}} =
               LLM.call("repeat query", [], opts)

      assert Cache.size() == 1

      # Disable the provider to prove the second request is served from cache
      ProviderRegistry.disable_provider(:cached_mock)

      assert {:ok, %Response{content: "Handled by fast-v1: repeat query"}} =
               LLM.call("repeat query", [], opts)

      stats = Telemetry.get_provider_stats(:cached_mock)
      assert stats.total_requests == 2
      assert stats.cache_hits == 1
    end
  end
end
