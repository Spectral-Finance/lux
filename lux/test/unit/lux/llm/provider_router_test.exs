defmodule Lux.LLM.ProviderRouterTest do
  use ExUnit.Case, async: false
  alias Lux.LLM.ProviderRouter

  setup do
    ProviderRouter.init_store()
    :ets.delete_all_objects(:lux_llm_provider_router_store)
    :ok
  end

  test "selects optimal provider, falls back on failure, caches responses, and tracks costs" do
    {:ok, _} =
      ProviderRouter.register_provider(%{
        id: :primary_openai,
        model: "gpt-4o",
        priority: 1,
        cost_per_1k_tokens: 0.005,
        capabilities: [:chat, :reasoning],
        handler: fn _prompt -> {:error, :rate_limited} end
      })

    {:ok, _} =
      ProviderRouter.register_provider(%{
        id: :backup_anthropic,
        model: "claude-3-7-sonnet",
        priority: 2,
        cost_per_1k_tokens: 0.003,
        capabilities: [:chat, :reasoning],
        handler: fn prompt -> {:ok, %{content: "Solved: #{prompt}", tokens: 500}} end
      })

    # Fallback should automatically route to :backup_anthropic when :primary_openai fails
    {:ok, res1} = ProviderRouter.complete("Analyze portfolio risk")
    assert res1.provider_id == :backup_anthropic
    assert res1.cached == false
    assert res1.cost_usd == 0.0015

    # Second identical call hits cache
    {:ok, res2} = ProviderRouter.complete("Analyze portfolio risk")
    assert res2.cached == true

    summary = ProviderRouter.telemetry_summary()
    assert summary.total_calls == 1
    assert summary.by_provider[:backup_anthropic].total_tokens == 500
  end
end
