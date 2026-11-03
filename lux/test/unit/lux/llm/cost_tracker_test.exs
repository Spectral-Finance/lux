defmodule Lux.LLM.CostTrackerTest do
  use UnitCase, async: true

  alias Lux.LLM.CostTracker

  describe "calculate_cost/3" do
    test "calculates exact USD cost for token counts" do
      # gpt-4o-mini: $0.15/1M input, $0.60/1M output
      # 10,000 prompt tokens = 10,000 * 0.15 / 1e6 = 0.0015
      # 1,000 completion tokens = 1,000 * 0.60 / 1e6 = 0.0006
      # Total = 0.0021
      cost = CostTracker.calculate_cost("gpt-4o-mini", 10_000, 1_000)

      assert cost.model == "gpt-4o-mini"
      assert cost.total_tokens == 11_000
      assert cost.prompt_cost_usd == 0.0015
      assert cost.completion_cost_usd == 0.0006
      assert cost.total_cost_usd == 0.0021
    end
  end
end
