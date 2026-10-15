defmodule Lux.LLM.PerplexityTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.Perplexity

  test "builds grounded Perplexity search payload and deduplicates citations" do
    {:ok, req} =
      Perplexity.build_search_request(%{
        query: "Latest Uniswap V4 hooks security audits",
        model: "sonar-reasoning-pro",
        recency: "week",
        stream: true
      })

    assert req.model == "sonar-reasoning-pro"
    assert req.return_citations == true
    assert req.stream == true

    citations =
      Perplexity.extract_citations(%{
        citations: ["https://docs.uniswap.org", "https://cantina.xyz", "https://docs.uniswap.org"]
      })

    assert citations == ["https://docs.uniswap.org", "https://cantina.xyz"]
  end
end
