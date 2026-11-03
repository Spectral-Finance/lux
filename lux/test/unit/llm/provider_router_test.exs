defmodule Lux.LLM.ProviderRouterTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.ProviderRouter

  test "falls back to secondary provider when primary fails" do
    providers = [:primary_llm, :secondary_llm]

    res =
      ProviderRouter.execute_with_fallback(providers, fn
        :primary_llm -> {:error, :rate_limited}
        :secondary_llm -> {:ok, "completed"}
      end)

    assert {:ok, %{provider: :secondary_llm, response: "completed"}} = res
    assert ProviderRouter.estimate_cost_usd(1000, 500, 2.0, 8.0) == 0.006
  end
end
