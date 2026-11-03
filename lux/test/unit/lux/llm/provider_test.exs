defmodule Lux.LLM.ProviderTest do
  use UnitCase, async: true

  alias Lux.LLM.Registry
  alias Lux.LLM.CostTracker
  alias Lux.LLM.Cache
  alias Lux.LLM.PerformanceMonitor
  alias Lux.LLM.Response

  describe "Lux.LLM.Registry" do
    test "lists default enabled providers" do
      providers = Registry.list_enabled_providers()
      assert is_list(providers)
      assert length(providers) >= 4

      ids = Enum.map(providers, & &1.id)
      assert :openai in ids
      assert :anthropic in ids
      assert :ollama in ids
    end

    test "gets provider by atom or binary id" do
      assert {:ok, prov1} = Registry.get_provider(:openai)
      assert prov1.name == "OpenAI"

      assert {:ok, prov2} = Registry.get_provider("anthropic")
      assert prov2.name == "Anthropic"
    end

    test "filters providers by capability" do
      local_providers = Registry.filter_by_capability(:local)
      assert length(local_providers) >= 1
      assert hd(local_providers).id == :ollama

      tool_providers = Registry.filter_by_capability([:tool_calling])
      assert length(tool_providers) >= 2
    end

    test "enables and disables providers dynamically" do
      assert :ok = Registry.disable_provider(:openai)
      assert {:ok, prov} = Registry.get_provider(:openai)
      assert prov.enabled == false

      assert :ok = Registry.enable_provider(:openai)
      assert {:ok, prov_again} = Registry.get_provider(:openai)
      assert prov_again.enabled == true
    end
  end

  describe "Lux.LLM.CostTracker" do
    setup do
      CostTracker.reset!()
      :ok
    end

    test "calculates cost accurately" do
      # 1,000,000 prompt tokens for gpt-4o = $2.50
      cost = CostTracker.calculate_cost(1_000_000, 0, "gpt-4o")
      assert cost == 2.5

      # Free for ollama
      assert CostTracker.calculate_cost(500_000, 500_000, "ollama") == 0.0
    end

    test "records usage and summarizes spend" do
      CostTracker.record_usage(:openai, "gpt-4o", 1000, 500)
      CostTracker.record_usage(:anthropic, "claude-3-5-sonnet-20241022", 2000, 800)

      summary = CostTracker.get_summary()
      assert summary.total_requests == 2
      assert summary.total_tokens == 4300
      assert summary.total_cost_usd > 0.0
      assert Map.has_key?(summary.by_provider, "openai")
    end

    test "verifies budget boundaries" do
      CostTracker.record_usage(:openai, "gpt-4o", 100, 50)
      assert {:ok, :within_budget, _spend} = CostTracker.check_budget_limit(10.0)
    end
  end

  describe "Lux.LLM.Cache" do
    setup do
      Cache.clear!()
      :ok
    end

    test "stores and retrieves deterministic responses" do
      prompt = "What is Elixir?"
      model = "gpt-4o"
      key = Cache.generate_key(prompt, model)

      assert Cache.get(key) == :miss

      response = %Response{content: "Elixir is a dynamic, functional language"}
      assert :ok = Cache.put(key, response, 3600)

      assert {:ok, cached} = Cache.get(key)
      assert cached.content == response.content

      stats = Cache.stats()
      assert stats.hits == 1
      assert stats.misses == 1
    end
  end

  describe "Lux.LLM.PerformanceMonitor" do
    setup do
      PerformanceMonitor.reset!()
      :ok
    end

    test "measures latency and records report" do
      {:ok, result, metric} =
        PerformanceMonitor.measure(:openai, "gpt-4o", fn ->
          {:ok, "completed"}
        end)

      assert result == "completed"
      assert metric.status == :success
      assert is_integer(metric.duration_ms)

      report = PerformanceMonitor.get_report()
      assert report.total_calls == 1
      assert report.success_count == 1
      assert report.error_count == 0
    end
  end
end
