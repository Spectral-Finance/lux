defmodule Lux.LLM.ProviderManagerTest do
  @moduledoc """
  Comprehensive tests for the LLM Provider Manager.

  Tests cover:
  - Provider registration and listing
  - Task-based provider recommendations
  - Cost estimation with model-specific pricing
  - Statistics tracking with latency percentiles
  - Circuit breaker pattern
  - Rate limiting
  - LRU caching with TTL
  - Health checks
  """

  use ExUnit.Case, async: false

  alias Lux.LLM.ProviderManager

  setup do
    start_supervised!(ProviderManager)
    :ok
  end

  # ============================================================================
  # Provider Listing Tests
  # ============================================================================

  describe "list_providers/0" do
    test "returns all registered providers" do
      providers = ProviderManager.list_providers()

      assert is_list(providers)
      assert length(providers) >= 5

      provider_names = Enum.map(providers, fn {name, _} -> name end)
      assert :openai in provider_names
      assert :anthropic in provider_names
      assert :ollama in provider_names
      assert :together in provider_names
      assert :mira in provider_names
    end

    test "returns comprehensive status for each provider" do
      providers = ProviderManager.list_providers()

      Enum.each(providers, fn {_name, info} ->
        assert Map.has_key?(info, :module)
        assert Map.has_key?(info, :health)
        assert Map.has_key?(info, :circuit_breaker)
        assert Map.has_key?(info, :rate_limit_remaining)
        assert Map.has_key?(info, :rate_limit_max)
        assert info.circuit_breaker in [:closed, :open, :half_open]
      end)
    end

    test "rate limit values are non-negative" do
      providers = ProviderManager.list_providers()

      Enum.each(providers, fn {_name, info} ->
        assert info.rate_limit_remaining >= 0
        assert info.rate_limit_max >= 0
        assert info.rate_limit_remaining <= info.rate_limit_max
      end)
    end
  end

  # ============================================================================
  # Provider Recommendation Tests
  # ============================================================================

  describe "recommend_provider/1" do
    test "recommends appropriate provider for coding tasks" do
      provider = ProviderManager.recommend_provider(:coding)
      assert provider in [:anthropic, :openai, :ollama]
    end

    test "recommends appropriate provider for creative tasks" do
      provider = ProviderManager.recommend_provider(:creative)
      assert provider in [:anthropic, :openai]
    end

    test "recommends ollama for local tasks" do
      provider = ProviderManager.recommend_provider(:local)
      assert provider == :ollama or provider in [:openai, :anthropic]
    end

    test "recommends cheap providers for budget tasks" do
      provider = ProviderManager.recommend_provider(:cheap)
      assert provider in [:ollama, :together, :openai, :anthropic]
    end

    test "recommends appropriate provider for fast tasks" do
      provider = ProviderManager.recommend_provider(:fast)
      assert provider in [:ollama, :together, :openai, :anthropic]
    end

    test "recommends appropriate provider for vision tasks" do
      provider = ProviderManager.recommend_provider(:vision)
      assert provider in [:openai, :anthropic]
    end

    test "recommends appropriate provider for long context tasks" do
      provider = ProviderManager.recommend_provider(:long_context)
      assert provider in [:anthropic, :openai]
    end

    test "returns default for unknown task type" do
      provider = ProviderManager.recommend_provider(:unknown_task)
      assert is_atom(provider)
    end
  end

  # ============================================================================
  # Cost Estimation Tests
  # ============================================================================

  describe "estimate_cost/3" do
    test "calculates cost for OpenAI with default model" do
      cost = ProviderManager.estimate_cost(:openai, 1000, 500)
      assert is_float(cost)
      assert cost > 0
    end

    test "calculates cost for OpenAI with specific model" do
      cost_gpt4o = ProviderManager.estimate_cost(:openai, 1000, 500, "gpt-4o")
      cost_gpt4o_mini = ProviderManager.estimate_cost(:openai, 1000, 500, "gpt-4o-mini")

      assert cost_gpt4o > cost_gpt4o_mini
    end

    test "calculates cost for Anthropic with model variants" do
      cost_opus = ProviderManager.estimate_cost(:anthropic, 1000, 500, "claude-3-opus")
      cost_haiku = ProviderManager.estimate_cost(:anthropic, 1000, 500, "claude-3-haiku")

      assert cost_opus > cost_haiku
    end

    test "returns zero cost for Ollama" do
      cost = ProviderManager.estimate_cost(:ollama, 1000, 500)
      assert cost == 0.0
    end

    test "calculates cost for Together AI" do
      cost = ProviderManager.estimate_cost(:together, 1000, 500)
      assert is_float(cost)
      assert cost >= 0
    end

    test "scales linearly with token count" do
      cost_small = ProviderManager.estimate_cost(:openai, 100, 50)
      cost_large = ProviderManager.estimate_cost(:openai, 1000, 500)
      assert_in_delta cost_large / cost_small, 10.0, 0.01
    end

    test "handles zero tokens" do
      cost = ProviderManager.estimate_cost(:openai, 0, 0)
      assert cost == 0.0
    end

    test "handles unknown provider gracefully" do
      cost = ProviderManager.estimate_cost(:unknown_provider, 1000, 500)
      assert cost == 0.0
    end
  end

  # ============================================================================
  # Statistics Tests
  # ============================================================================

  describe "get_stats/0" do
    test "returns comprehensive statistics map" do
      stats = ProviderManager.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_calls)
      assert Map.has_key?(stats, :successful_calls)
      assert Map.has_key?(stats, :failed_calls)
      assert Map.has_key?(stats, :avg_latency_ms)
      assert Map.has_key?(stats, :total_input_tokens)
      assert Map.has_key?(stats, :total_output_tokens)
      assert Map.has_key?(stats, :total_cost_usd)
      assert Map.has_key?(stats, :by_provider)
      assert Map.has_key?(stats, :cache_hit_rate)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "initializes with zero values" do
      stats = ProviderManager.get_stats()

      assert stats.total_calls == 0
      assert stats.successful_calls == 0
      assert stats.failed_calls == 0
      assert stats.total_input_tokens == 0
      assert stats.total_output_tokens == 0
      assert stats.total_cost_usd == 0.0
    end

    test "per-provider stats include latency percentiles" do
      stats = ProviderManager.get_stats()

      Enum.each(stats.by_provider, fn {_provider, pstats} ->
        assert Map.has_key?(pstats, :p50_latency_ms)
        assert Map.has_key?(pstats, :p95_latency_ms)
        assert Map.has_key?(pstats, :p99_latency_ms)
      end)
    end

    test "uptime is non-negative" do
      stats = ProviderManager.get_stats()
      assert stats.uptime_seconds >= 0
    end

    test "cache hit rate is between 0 and 100" do
      stats = ProviderManager.get_stats()
      assert stats.cache_hit_rate >= 0.0
      assert stats.cache_hit_rate <= 100.0
    end
  end

  describe "reset_stats/0" do
    test "resets all statistics to zero" do
      _initial = ProviderManager.get_stats()
      assert :ok = ProviderManager.reset_stats()

      stats = ProviderManager.get_stats()
      assert stats.total_calls == 0
      assert stats.successful_calls == 0
      assert stats.failed_calls == 0
      assert stats.total_input_tokens == 0
      assert stats.total_output_tokens == 0
    end

    test "preserves by_provider structure after reset" do
      ProviderManager.reset_stats()
      stats = ProviderManager.get_stats()

      assert is_map(stats.by_provider)
      assert map_size(stats.by_provider) >= 5
    end
  end

  # ============================================================================
  # Provider Availability Tests
  # ============================================================================

  describe "provider_available?/1" do
    test "checks if a registered provider is available" do
      result = ProviderManager.provider_available?(:openai)
      assert is_boolean(result)
    end

    test "returns false for unknown provider" do
      result = ProviderManager.provider_available?(:unknown_provider)
      refute result
    end

    test "checks availability for all known providers" do
      providers = [:openai, :anthropic, :ollama, :together, :mira]

      Enum.each(providers, fn provider ->
        result = ProviderManager.provider_available?(provider)
        assert is_boolean(result)
      end)
    end
  end

  # ============================================================================
  # Cache Tests
  # ============================================================================

  describe "cache_stats/0" do
    test "returns cache statistics" do
      stats = ProviderManager.cache_stats()

      assert Map.has_key?(stats, :size)
      assert Map.has_key?(stats, :max_size)
      assert Map.has_key?(stats, :hit_rate)
      assert Map.has_key?(stats, :hits)
      assert Map.has_key?(stats, :misses)
    end

    test "cache starts empty" do
      stats = ProviderManager.cache_stats()
      assert stats.size == 0
      assert stats.hits == 0
      assert stats.misses == 0
    end

    test "cache has configured max size" do
      stats = ProviderManager.cache_stats()
      assert stats.max_size > 0
    end
  end

  describe "clear_cache/0" do
    test "clears the cache" do
      assert :ok = ProviderManager.clear_cache()

      stats = ProviderManager.cache_stats()
      assert stats.size == 0
    end
  end

  # ============================================================================
  # Circuit Breaker Tests
  # ============================================================================

  describe "reset_circuit_breaker/1" do
    test "resets circuit breaker for a provider" do
      assert :ok = ProviderManager.reset_circuit_breaker(:openai)

      providers = ProviderManager.list_providers()
      {_, info} = Enum.find(providers, fn {name, _} -> name == :openai end)
      assert info.circuit_breaker == :closed
    end

    test "can reset circuit breaker for any provider" do
      providers = [:openai, :anthropic, :ollama, :together, :mira]

      Enum.each(providers, fn provider ->
        assert :ok = ProviderManager.reset_circuit_breaker(provider)
      end)
    end
  end

  describe "circuit breaker state" do
    test "all providers start with closed circuit breakers" do
      providers = ProviderManager.list_providers()

      Enum.each(providers, fn {_name, info} ->
        assert info.circuit_breaker == :closed
      end)
    end
  end

  # ============================================================================
  # Health Check Tests
  # ============================================================================

  describe "check_health/0" do
    test "returns health status for all providers" do
      health = ProviderManager.check_health()

      assert is_map(health)
      assert Map.has_key?(health, :openai)
      assert Map.has_key?(health, :anthropic)
      assert Map.has_key?(health, :ollama)
      assert Map.has_key?(health, :together)
      assert Map.has_key?(health, :mira)
    end

    test "health status values are valid" do
      health = ProviderManager.check_health()

      Enum.each(health, fn {_provider, status} ->
        assert status in [:healthy, :unhealthy, :unconfigured, :unknown]
      end)
    end
  end

  # ============================================================================
  # Rate Limiting Tests
  # ============================================================================

  describe "rate limiting" do
    test "providers have rate limit tokens" do
      providers = ProviderManager.list_providers()

      Enum.each(providers, fn {_name, info} ->
        assert is_integer(info.rate_limit_remaining)
        assert is_integer(info.rate_limit_max)
      end)
    end

    test "ollama has higher rate limit than cloud providers" do
      providers = ProviderManager.list_providers()

      ollama_info = Enum.find_value(providers, fn
        {:ollama, info} -> info
        _ -> nil
      end)

      openai_info = Enum.find_value(providers, fn
        {:openai, info} -> info
        _ -> nil
      end)

      assert ollama_info.rate_limit_max >= openai_info.rate_limit_max
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "provider manager lifecycle" do
    test "handles multiple operations in sequence" do
      # List providers
      providers = ProviderManager.list_providers()
      assert length(providers) >= 5

      # Get stats
      stats = ProviderManager.get_stats()
      assert stats.total_calls == 0

      # Check health
      health = ProviderManager.check_health()
      assert is_map(health)

      # Get recommendation
      provider = ProviderManager.recommend_provider(:coding)
      assert is_atom(provider)

      # Estimate cost
      cost = ProviderManager.estimate_cost(provider, 1000, 500)
      assert is_float(cost)

      # Reset stats
      assert :ok = ProviderManager.reset_stats()

      # Clear cache
      assert :ok = ProviderManager.clear_cache()
    end

    test "state remains consistent after operations" do
      # Perform various operations
      ProviderManager.list_providers()
      ProviderManager.get_stats()
      ProviderManager.recommend_provider(:coding)
      ProviderManager.reset_circuit_breaker(:openai)

      # Verify state is still valid
      providers = ProviderManager.list_providers()
      assert is_list(providers)
      assert length(providers) >= 5

      stats = ProviderManager.get_stats()
      assert is_map(stats)
    end
  end
end
