defmodule Lux.LLM.PerplexityTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.Perplexity
  alias Lux.LLM.Perplexity.Config

  describe "select_model/2" do
    test "selects specialized Sonar models by task and budget" do
      assert Perplexity.select_model(:deep_research) == "sonar-deep-research"
      assert Perplexity.select_model(:reasoning, max_cost_tier: :low) == "sonar-reasoning"
      assert Perplexity.select_model(:knowledge_intensive, max_cost_tier: :high) == "sonar-pro"
    end
  end

  describe "build_payload/2" do
    test "constructs payload with domain and recency filters" do
      cfg = %Config{
        model: "sonar-pro",
        search_domain_filter: ["arxiv.org", "ethereum.org"],
        search_recency_filter: "week",
        stream: true
      }

      assert {:ok, payload} = Perplexity.build_payload("Explain EIP-4337 paymasters", cfg)
      assert payload.model == "sonar-pro"
      assert payload.search_domain_filter == ["arxiv.org", "ethereum.org"]
      assert payload.search_recency_filter == "week"
      assert payload.stream == true
    end

    test "rejects unsupported models and empty prompts" do
      assert {:error, :unsupported_model} = Perplexity.build_payload("Hi", %Config{model: "unknown"})
      assert {:error, :empty_prompt} = Perplexity.build_payload("   ", %Config{model: "sonar"})
    end
  end

  describe "estimate_cost/4" do
    test "computes token and search fee cost accurately" do
      assert {:ok, cost} = Perplexity.estimate_cost("sonar-pro", 10_000, 2_000, 1)
      # 10k * $3/1M ($0.03) + 2k * $15/1M ($0.03) + 1 * $5/1k ($0.005) = $0.065
      assert cost.total_usd == 0.065
    end
  end
end
