defmodule Lux.Integration.LLM.PerplexityAITest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.LLM.PerplexityAI
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal
  alias Lux.SignalSchema

  describe "models API" do
    test "returns list of available models with pricing" do
      models = PerplexityAI.models()
      assert length(models) >= 3

      sonar = Enum.find(models, fn m -> m.id == "sonar" end)
      assert sonar
      assert sonar.name == "Sonar"
      assert sonar.online == true
      assert sonar.input_price_per_1m == 1.00
      assert sonar.output_price_per_1m == 1.00

      sonar_pro = Enum.find(models, fn m -> m.id == "sonar-pro" end)
      assert sonar_pro
      assert sonar_pro.input_price_per_1m == 3.00
      assert sonar_pro.output_price_per_1m == 15.00
    end
  end

  describe "cost estimation" do
    test "estimates cost for sonar model" do
      cost = PerplexityAI.estimate_cost("sonar", 1000, 500)
      # sonar: $1/M input + $1/M output = 0.001 + 0.0005 = 0.0015
      assert cost == 0.0015
    end

    test "estimates cost for sonar-pro model" do
      cost = PerplexityAI.estimate_cost("sonar-pro", 500, 1000)
      # sonar-pro: $3/M input + $15/M output = 0.0015 + 0.015 = 0.0165
      assert cost == 0.0165
    end

    test "estimates cost for sonar-deep-research model" do
      cost = PerplexityAI.estimate_cost("sonar-deep-research", 1000, 2000)
      # sonar-deep-research: $5/M input + $15/M output = 0.005 + 0.03 = 0.035
      assert cost == 0.035
    end

    test "returns 0 for unknown model" do
      cost = PerplexityAI.estimate_cost("unknown-model", 100, 100)
      assert cost == 0.0
    end
  end

  describe "cost from usage" do
    test "calculates cost from API usage response" do
      usage = %{
        "model" => "sonar-pro",
        "prompt_tokens" => 500,
        "completion_tokens" => 1000
      }

      result = PerplexityAI.cost_from_usage(usage)
      assert result.cost == 0.0165
      assert result.model == "sonar-pro"
      assert result.input_tokens == 500
      assert result.output_tokens == 1000
    end

    test "defaults to sonar when model not specified" do
      usage = %{
        "prompt_tokens" => 1000,
        "completion_tokens" => 1000
      }

      result = PerplexityAI.cost_from_usage(usage)
      # sonar: 1/1M + 1/1M = 0.002
      assert result.cost == 0.002
      assert result.model == "sonar"
    end
  end

  describe "parsing content" do
    test "parses JSON content" do
      assert {:ok, %{"foo" => "bar"}} = PerplexityAI.parse_content(~s({"foo": "bar"}))
    end

    test "returns plain text for non-JSON" do
      assert {:ok, "hello world"} = PerplexityAI.parse_content("hello world")
    end

    test "returns nil for nil content" do
      assert {:ok, nil} = PerplexityAI.parse_content(nil)
    end
  end

  describe "parsing tool calls" do
    test "handles nil tool calls" do
      assert {:ok, nil} = PerplexityAI.execute_tool_calls(nil)
    end

    test "handles empty tool calls" do
      assert {:ok, []} = PerplexityAI.execute_tool_calls([])
    end

    test "parses tool call arguments" do
      calls = [
        %{
          "function" => %{
            "name" => "test_func",
            "arguments" => ~s({"key": "value"})
          }
        }
      ]

      assert {:ok, [{"test_func", %{"key" => "value"}}]} = PerplexityAI.execute_tool_calls(calls)
    end

    test "handles unparsable arguments as strings" do
      calls = [
        %{
          "function" => %{
            "name" => "test_func",
            "arguments" => "not-json"
          }
        }
      ]

      assert {:ok, [{"test_func", "not-json"}]} = PerplexityAI.execute_tool_calls(calls)
    end
  end
end
