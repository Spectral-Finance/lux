defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.OpenRouter
  alias Lux.LLM.OpenRouter.QuotaTracker

  describe "build_request/2" do
    test "creates unified payload with fallback routing" do
      assert {:ok, req} =
               OpenRouter.build_request("Summarize DeFi yields",
                 model: "anthropic/claude-3.5-sonnet",
                 fallback_models: ["openai/gpt-4o", "meta-llama/llama-3.3-70b-instruct"]
               )

      assert req.route == "fallback"
      assert req.models == [
               "anthropic/claude-3.5-sonnet",
               "openai/gpt-4o",
               "meta-llama/llama-3.3-70b-instruct"
             ]
    end
  end

  describe "check_quota/2 and retry_decision/3" do
    test "enforces rate limits and USD budgets" do
      tracker = %QuotaTracker{max_requests_per_minute: 2, max_budget_usd: 1.0}
      assert {:ok, tracker} = OpenRouter.check_quota(tracker, 0.4)
      assert {:ok, tracker} = OpenRouter.check_quota(tracker, 0.4)
      assert {:error, :rate_limited} = OpenRouter.check_quota(tracker, 0.1)
    end

    test "computes exponential backoff for retryable HTTP statuses" do
      assert {:retry, 500} = OpenRouter.retry_decision(429, 0, 3)
      assert {:retry, 1000} = OpenRouter.retry_decision(503, 1, 3)
      assert {:halt, :max_retries_exceeded} = OpenRouter.retry_decision(429, 3, 3)
      assert {:halt, :non_retryable} = OpenRouter.retry_decision(400, 0, 3)
    end
  end
end
