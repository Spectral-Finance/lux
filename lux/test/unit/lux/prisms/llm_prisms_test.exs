defmodule Lux.Prisms.LLMPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.LLM.ProviderCallPrism
  alias Lux.Prisms.LLM.ModelSelectPrism
  alias Lux.Prisms.LLM.FallbackPrism
  alias Lux.Prisms.LLM.CostAnalyticsPrism
  alias Lux.Prisms.LLM.CachePrism

  describe "ModelSelectPrism" do
    test "selects provider based on strategy" do
      {:ok, result} =
        ModelSelectPrism.handler(
          %{"strategy" => "cost_optimized", "require_tools" => false},
          %{}
        )

      assert is_binary(result.provider_id)
      assert is_binary(result.model)
      assert result.cost_tier in ["free", "economy"]
    end
  end

  describe "CachePrism" do
    test "puts and retrieves cache items" do
      prompt = "Explain quantum computing"
      model = "gpt-4o"
      content = "Quantum computing uses qubits..."

      {:ok, put_res} =
        CachePrism.handler(
          %{
            "action" => "put",
            "prompt" => prompt,
            "model" => model,
            "content" => content
          },
          %{}
        )

      assert put_res.hit == true
      assert put_res.content == content

      {:ok, get_res} =
        CachePrism.handler(
          %{
            "action" => "get",
            "prompt" => prompt,
            "model" => model
          },
          %{}
        )

      assert get_res.hit == true
      assert get_res.content == content
    end
  end

  describe "CostAnalyticsPrism" do
    test "records usage tokens and returns summary" do
      {:ok, rec_res} =
        CostAnalyticsPrism.handler(
          %{
            "action" => "record",
            "provider" => "openai",
            "model" => "gpt-4o",
            "prompt_tokens" => 500,
            "completion_tokens" => 200
          },
          %{}
        )

      assert is_number(rec_res.total_cost_usd)
      assert rec_res.total_tokens >= 700
      assert String.contains?(rec_res.status, "recorded")
    end

    test "checks budget threshold" do
      {:ok, check_res} =
        CostAnalyticsPrism.handler(
          %{
            "action" => "check_budget",
            "budget_limit_usd" => 50.0
          },
          %{}
        )

      assert check_res.status == "within_budget"
    end
  end

  describe "ProviderCallPrism" do
    test "executes call through registered provider" do
      {:ok, result} =
        ProviderCallPrism.handler(
          %{
            "prompt" => "Hello AI",
            "provider" => "openai"
          },
          %{}
        )

      assert result.success == true
      assert result.provider == "openai"
      assert is_binary(result.model)
    end
  end
end
