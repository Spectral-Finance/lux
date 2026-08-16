defmodule Lux.LLM.ProvidersTest do
  @moduledoc """
  Test suite for Lux.LLM.Providers.
  """

  use UnitCase, async: false
  alias Lux.LLM.Providers

  defmodule SuccessfulProvider do
    @moduledoc false
    @behaviour Lux.LLM

    @impl true
    def call(prompt, _tools, _options) do
      Process.put({__MODULE__, :calls}, Process.get({__MODULE__, :calls}, 0) + 1)

      {:ok,
       %Lux.LLM.Response{
         content: prompt,
         tool_calls: [],
         finish_reason: "stop"
       }}
    end
  end

  setup_all do
    if Process.whereis(Providers) == nil do
      start_supervised!(Providers)
    end

    :ok
  end

  setup do
    Providers.reset_all()
    Process.delete({SuccessfulProvider, :calls})
    :ok
  end

  describe "provider registration" do
    test "registers and lists built-in providers" do
      providers = Providers.list_providers()
      assert length(providers) >= 4
      names = Enum.map(providers, & &1.name)
      assert :openai in names
      assert :anthropic in names
      assert :together_ai in names
      assert :mira in names
    end

    test "registers custom provider" do
      :ok =
        Providers.register(:test_provider, %{
          module: SuccessfulProvider,
          models: ~w(test-model),
          capabilities: [:tools],
          cost_per_input_token: %{default: 1.0e-6},
          cost_per_output_token: %{default: 2.0e-6},
          priority: 10
        })

      assert {:ok, _provider} = Providers.get_provider(:test_provider)
      providers = Providers.list_providers()
      assert :test_provider in Enum.map(providers, & &1.name)
    end

    test "unregisters provider" do
      :ok =
        Providers.register(:test_provider, %{
          module: SuccessfulProvider,
          models: ["test-model"]
        })

      :ok = Providers.unregister(:test_provider)
      assert {:error, :not_found} = Providers.get_provider(:test_provider)
    end
  end

  describe "provider selection" do
    test "selects provider by task type" do
      # :cheap should pick mira (lowest cost)
      provider = Providers.select_provider(task_type: :cheap)
      assert provider.name == :mira

      # :fast should pick a mini/haiku/turbo model
      provider = Providers.select_provider(task_type: :fast)
      # Could be openai (gpt-4o-mini), anthropic (haiku), or together_ai
      assert provider.enabled == true
    end

    test "selects provider by model name" do
      provider = Providers.select_provider(model: "gpt-4o")
      assert provider.name == :openai

      provider = Providers.select_provider(model: "claude-3-sonnet")
      assert provider.name == :anthropic
    end
  end

  describe "circuit breaker" do
    test "circuit opens after threshold failures" do
      # Force reset
      Providers.record_success(:openai)
      assert Providers.circuit_open?(:openai) == false

      # Record failures up to threshold
      for _ <- 1..5 do
        Providers.record_failure(:openai)
      end

      assert Providers.circuit_open?(:openai) == true
    end

    test "success resets circuit" do
      Providers.record_failure(:anthropic)
      Providers.record_failure(:anthropic)
      Providers.record_success(:anthropic)
      assert Providers.circuit_open?(:anthropic) == false
    end
  end

  describe "cost tracking" do
    test "tracks cost and returns stats" do
      Providers.track_cost(:openai, "gpt-4o", 100, 50, 500, true)
      Providers.track_cost(:openai, "gpt-4o", 200, 100, 600, true)
      Providers.track_cost(:anthropic, "claude-3-sonnet", 50, 25, 400, false)

      stats = Providers.get_stats()
      assert stats.total_requests == 3
      assert stats.successful == 2
      assert stats.failed == 1
      assert stats.total_prompt_tokens == 350
      assert stats.total_completion_tokens == 175
      assert stats.success_rate == 2.0 / 3.0
      assert_in_delta stats.estimated_cost_usd, 0.002775, 0.0000001
      assert stats.by_provider[:openai].count == 2
      assert stats.by_provider[:anthropic].count == 1
    end

    test "filters stats by provider" do
      Providers.track_cost(:together_ai, "mistral", 50, 50, 300, true)
      stats = Providers.get_stats(provider: :together_ai)
      assert stats.total_requests == 1
      assert stats.by_provider[:together_ai].count == 1
    end
  end

  describe "caching" do
    test "caches and retrieves response" do
      response = %Lux.LLM.Response{content: "Hello", tool_calls: [], finish_reason: "stop"}
      :ok = Providers.cache_response("test_key", response)
      assert {:ok, ^response} = Providers.get_cached("test_key")
    end

    test "returns expired for expired cache" do
      response = %Lux.LLM.Response{content: "Hello", tool_calls: [], finish_reason: "stop"}
      # Cache with 0 TTL (already expired)
      :ok = Providers.cache_response("expired_key", response, 0)
      :timer.sleep(10)
      assert {:error, :expired} = Providers.get_cached("expired_key")
    end

    test "flushes cache" do
      response = %Lux.LLM.Response{content: "Hello", tool_calls: [], finish_reason: "stop"}
      :ok = Providers.cache_response("flush_key", response)
      assert {:ok, ^response} = Providers.get_cached("flush_key")
      Providers.flush_cache("flush_key")
      assert {:error, :not_found} = Providers.get_cached("flush_key")
    end
  end

  describe "fallback chain" do
    test "excludes circuit-broken providers from fallback" do
      # Open the circuit for openai
      for _ <- 1..5 do
        Providers.record_failure(:openai)
      end

      chain = Providers.select_fallback_chain()
      names = Enum.map(chain, & &1.name)
      refute :openai in names
      assert :anthropic in names
    end

    test "calls a successful provider and caches the response with map options" do
      :ok =
        Providers.register(:successful, %{
          module: SuccessfulProvider,
          models: ["test-model"],
          capabilities: [],
          cost_per_input_token: %{default: 0.0},
          cost_per_output_token: %{default: 0.0},
          priority: 0
        })

      options = %{model: "test-model", cache: true}

      assert {:ok, %Lux.LLM.Response{content: "hello"} = response} =
               Providers.call("hello", [], options)

      assert {:ok, ^response} = Providers.call("hello", [], options)
      assert Process.get({SuccessfulProvider, :calls}) == 1
    end
  end
end
