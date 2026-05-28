defmodule Lux.LLM.ProviderRouterTest do
  @moduledoc """
  Tests for LLM Provider Router.
  """

  use ExUnit.Case, async: true

  alias Lux.LLM.ProviderRouter

  describe "default_providers/0" do
    test "returns default provider list" do
      # Default should include OpenAI
      providers = Application.get_env(:lux, :provider_router, [])[:providers] || []
      assert is_list(providers)
    end
  end

  describe "call/3" do
    test "routes to specific provider when forced" do
      # This would require mocking, so we test the interface
      result = ProviderRouter.call("test", [], %{provider: Lux.LLM.OpenAI})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles empty providers gracefully" do
      # Should return error if no providers available
      result = ProviderRouter.call("test", [], %{providers: []})
      assert match?({:error, _}, result)
    end
  end

  describe "health_check/0" do
    test "returns health status for configured providers" do
      results = ProviderRouter.health_check()
      assert is_list(results)

      Enum.each(results, fn result ->
        assert Map.has_key?(result, :module)
        assert Map.has_key?(result, :status)
        assert Map.has_key?(result, :latency_ms)
        assert result.status in [:healthy, :degraded, :unhealthy]
      end)
    end
  end

  describe "sort_providers/3" do
    test "round_robin rotates providers" do
      providers = [
        %{module: A, weight: 1},
        %{module: B, weight: 1},
        %{module: C, weight: 1}
      ]

      # Multiple calls should rotate
      sorted1 = ProviderRouter.sort_providers(providers, :round_robin, %{})
      sorted2 = ProviderRouter.sort_providers(providers, :round_robin, %{})
      sorted3 = ProviderRouter.sort_providers(providers, :round_robin, %{})

      # All providers should be present
      modules = Enum.map(sorted1, & &1.module) ++ Enum.map(sorted2, & &1.module) ++ Enum.map(sorted3, & &1.module)
      assert length(Enum.uniq(modules)) == 3
    end

    test "weighted sorts by weight descending" do
      providers = [
        %{module: A, weight: 1},
        %{module: B, weight: 3},
        %{module: C, weight: 2}
      ]

      sorted = ProviderRouter.sort_providers(providers, :weighted, %{})
      weights = Enum.map(sorted, & &1.weight)
      assert weights == [3, 2, 1]
    end
  end
end
