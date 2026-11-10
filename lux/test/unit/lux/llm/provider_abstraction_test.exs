defmodule Lux.LLM.ProviderAbstractionTest do
  use UnitAPICase, async: false

  alias Lux.LLM
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Response
  alias Lux.LLM.TelemetryAndCache

  setup do
    ProviderRegistry.reset_defaults()
    TelemetryAndCache.reset_all()
    :ok
  end

  describe "ProviderRegistry" do
    test "lists default providers and registers custom provider" do
      providers = ProviderRegistry.list_providers()
      ids = Enum.map(providers, & &1.id)
      assert :open_ai in ids
      assert :anthropic in ids
      assert :together_ai in ids
      assert :mira in ids

      {:ok, custom} =
        ProviderRegistry.register_provider(:custom_local, %{
          module: Lux.LLM.OpenAI,
          name: "Custom Local LLM",
          priority: 5,
          models: %{
            "local-7b" => %{
              tier: :low,
              input_cost_per_1k: 0.0,
              output_cost_per_1k: 0.0,
              latency_class: :fastest,
              capabilities: [:tool_use, :fast]
            }
          }
        })

      assert custom.name == "Custom Local LLM"
      assert {:ok, fetched} = ProviderRegistry.get_provider(:custom_local)
      assert Map.has_key?(fetched.models, "local-7b")
    end
  end

  describe "ModelSelector" do
    test "automatically selects cost-effective fast model when optimizing for cost" do
      {:ok, selection} =
        ModelSelector.select(%{
          complexity: :low,
          optimize_for: :cost,
          required_capabilities: [:tool_use, :cost_effective]
        })

      assert selection.model in ["gpt-4o-mini", "llama-3.1-8b-instruct", "mistral-7b-instruct"]
    end

    test "selects long_context capable model when required" do
      {:ok, selection} =
        ModelSelector.select(%{
          complexity: :high,
          required_capabilities: [:long_context, :reasoning]
        })

      assert selection.provider_id == :anthropic
    end

    test "skips unhealthy providers during selection" do
      ProviderRegistry.update_status(:anthropic, :unhealthy)

      assert {:error, :no_matching_model} =
               ModelSelector.select(%{required_capabilities: [:long_context]})
    end
  end

  describe "FallbackHandler and TelemetryAndCache via Lux.LLM.call_smart/3" do
    test "automatically falls back to secondary provider on primary failure and caches result" do
      runner = fn provider_id, _mod, prompt, _opts ->
        if provider_id == :open_ai do
          {:error, "rate_limit_exceeded"}
        else
          {:ok, %Response{content: "Fallback answer for: #{prompt}", finish_reason: "stop"}}
        end
      end

      assert {:ok, %Response{} = resp1} =
               LLM.call_smart("Explain zero-knowledge proofs", [], %{
                 provider: :open_ai,
                 fallback_providers: [:anthropic],
                 runner_fn: runner
               })

      assert resp1.provider == :anthropic
      assert resp1.cached == false
      assert resp1.content =~ "Fallback answer"

      metrics = TelemetryAndCache.get_metrics()
      assert Enum.any?(metrics, &(&1.provider_id == :open_ai and &1.failed_calls == 1))
      assert Enum.any?(metrics, &(&1.provider_id == :anthropic and &1.successful_calls == 1))
    end
  end
end
