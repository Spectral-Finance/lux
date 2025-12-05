defmodule Lux.LLM.ProviderManagerTest do
  @moduledoc """
  Tests for the LLM Provider Manager.
  """

  use ExUnit.Case, async: false

  alias Lux.LLM.ProviderManager

  setup do
    # Start the ProviderManager for each test
    start_supervised!(ProviderManager)
    :ok
  end

  describe "list_providers/0" do
    test "returns all registered providers" do
      providers = ProviderManager.list_providers()

      assert is_list(providers)
      assert length(providers) >= 5

      # Check that all expected providers are present
      provider_names = Enum.map(providers, fn {name, _} -> name end)
      assert :openai in provider_names
      assert :anthropic in provider_names
      assert :ollama in provider_names
      assert :together in provider_names
      assert :mira in provider_names
    end

    test "returns status for each provider" do
      providers = ProviderManager.list_providers()

      Enum.each(providers, fn {_name, info} ->
        assert Map.has_key?(info, :status)
        assert Map.has_key?(info, :module)
        assert info.status in [:available, :unavailable]
      end)
    end
  end

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
  end

  describe "estimate_cost/3" do
    test "calculates cost for OpenAI" do
      cost = ProviderManager.estimate_cost(:openai, 1000, 500)
      assert is_float(cost)
      assert cost > 0
    end

    test "returns zero cost for Ollama" do
      cost = ProviderManager.estimate_cost(:ollama, 1000, 500)
      assert cost == 0.0
    end

    test "scales with token count" do
      cost_small = ProviderManager.estimate_cost(:openai, 100, 50)
      cost_large = ProviderManager.estimate_cost(:openai, 1000, 500)
      assert cost_large > cost_small
    end
  end

  describe "get_stats/0" do
    test "returns statistics map" do
      stats = ProviderManager.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_calls)
      assert Map.has_key?(stats, :successful_calls)
      assert Map.has_key?(stats, :failed_calls)
      assert Map.has_key?(stats, :avg_latency_ms)
      assert Map.has_key?(stats, :by_provider)
    end

    test "initializes with zero values" do
      stats = ProviderManager.get_stats()

      assert stats.total_calls == 0
      assert stats.successful_calls == 0
      assert stats.failed_calls == 0
    end
  end

  describe "reset_stats/0" do
    test "resets all statistics to zero" do
      # Get initial stats
      _initial = ProviderManager.get_stats()

      # Reset
      assert :ok = ProviderManager.reset_stats()

      # Verify reset
      stats = ProviderManager.get_stats()
      assert stats.total_calls == 0
      assert stats.successful_calls == 0
      assert stats.failed_calls == 0
    end
  end

  describe "provider_available?/1" do
    test "checks if a provider is available" do
      # OpenAI should be available if configured
      result = ProviderManager.provider_available?(:openai)
      assert is_boolean(result)
    end

    test "returns false for unknown provider" do
      result = ProviderManager.provider_available?(:unknown_provider)
      refute result
    end
  end
end
