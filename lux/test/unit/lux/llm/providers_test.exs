defmodule Lux.LLM.ProvidersTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Providers

  setup do
    Providers.reset_all()
    Providers.init()
    :ok
  end

  describe "provider registry" do
    test "registers built-in providers" do
      providers = Providers.list_providers()
      assert length(providers) >= 4

      names = Enum.map(providers, & &1.name)
      assert :openai in names
      assert :anthropic in names
      assert :together_ai in names
      assert :mira in names
    end

    test "registers and unregisters custom providers" do
      assert Providers.get_provider(:test_provider) == {:error, :not_found}

      Providers.register(:test_provider, %{
        module: Lux.LLM.OpenAI,
        models: ["test-model"],
        capabilities: [:tools],
        priority: 10
      })

      assert {:ok, p} = Providers.get_provider(:test_provider)
      assert p.name == :test_provider
      assert p.priority == 10

      Providers.unregister(:test_provider)
      assert Providers.get_provider(:test_provider) == {:error, :not_found}
    end

    test "providers are ordered by priority" do
      providers = Providers.list_providers()
      priorities = Enum.map(providers, & &1.priority)
      assert priorities == Enum.sort(priorities)
    end
  end

  describe "auto model selection" do
    test "selects provider by model name" do
      p = Providers.select_provider(model: "gpt-4o")
      assert p.name == :openai
    end

    test "selects provider by task type" do
      p = Providers.select_provider(task_type: :fast)
      assert p.name in [:openai, :anthropic]
    end

    test "selects cheapest provider" do
      p = Providers.select_provider(task_type: :cheap)
      assert p.name == :mira
    end

    test "selects reasoning provider" do
      p = Providers.select_provider(task_type: :reasoning)
      assert p.name in [:openai, :anthropic]
    end

    test "respects capability requirements" do
      p = Providers.select_provider(capabilities: [:vision])
      assert p.name in [:openai, :anthropic]
    end
  end

  describe "fallback chain" do
    test "returns ordered list of available providers" do
      chain = Providers.select_fallback_chain()
      assert is_list(chain)
      assert length(chain) >= 4
    end

    test "excludes circuit-broken providers" do
      Providers.record_failure(:mira)
      Providers.record_failure(:mira)
      Providers.record_failure(:mira)
      Providers.record_failure(:mira)
      Providers.record_failure(:mira)

      chain = Providers.select_fallback_chain()
      refute Enum.any?(chain, &(&1.name == :mira))
    end
  end

  describe "circuit breaker" do
    test "starts closed" do
      refute Providers.circuit_open?(:openai)
    end

    test "opens after threshold failures" do
      for _ <- 1..5 do
        Providers.record_failure(:openai)
      end

      assert Providers.circuit_open?(:openai)
    end

    test "resets on success" do
      for _ <- 1..5 do
        Providers.record_failure(:openai)
      end

      assert Providers.circuit_open?(:openai)
      Providers.record_success(:openai)
      refute Providers.circuit_open?(:openai)
    end
  end

  describe "cost tracking" do
    test "tracks and aggregates costs" do
      Providers.track_cost(:openai, "gpt-4o", 100, 50, 500, true)
      Providers.track_cost(:openai, "gpt-4o", 200, 100, 600, true)
      Providers.track_cost(:anthropic, "claude-3", 150, 75, 800, true)

      stats = Providers.get_stats()
      assert stats.total_requests == 3
      assert stats.successful == 3
      assert stats.total_prompt_tokens == 450
      assert stats.total_completion_tokens == 225
      assert stats.by_provider[:openai].count == 2
      assert stats.by_provider[:anthropic].count == 1
    end
  end

  describe "caching" do
    test "caches and retrieves responses" do
      response = {:ok, %{content: "test"}}
      Providers.cache_response("test-key", response)

      assert {:ok, ^response} = Providers.get_cached("test-key")
    end

    test "returns not_found for unknown keys" do
      assert Providers.get_cached("nonexistent") == {:error, :not_found}
    end

    test "flushes all cache" do
      Providers.cache_response("key1", "val1")
      Providers.cache_response("key2", "val2")
      Providers.flush_cache(:all)

      assert Providers.get_cached("key1") == {:error, :not_found}
    end
  end
end
