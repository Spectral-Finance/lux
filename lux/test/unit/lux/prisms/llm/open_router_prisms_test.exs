defmodule Lux.Prisms.Llm.OpenRouterPrismsTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
  alias Lux.LLM.OpenRouter.KeyLimits
  alias Lux.Prisms.Llm.OpenRouter.ChatPrism
  alias Lux.Prisms.Llm.OpenRouter.CostPrism
  alias Lux.Prisms.Llm.OpenRouter.FallbackPrism
  alias Lux.Prisms.Llm.OpenRouter.KeyLimitsPrism
  alias Lux.Prisms.Llm.OpenRouter.ModelRoutePrism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "ChatPrism" do
    test "executes prompt completion and returns structured results" do
      Req.Test.stub(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "chat-1",
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Ethereum is a decentralized smart contract platform."
              }
            }
          ],
          "usage" => %{"prompt_tokens" => 15, "completion_tokens" => 10}
        })
      end)

      inputs = %{
        "prompt" => "What is Ethereum?",
        "model" => "openai/gpt-4o-mini",
        "api_key" => "sk-or-test"
      }

      assert {:ok, result} = ChatPrism.handler(inputs, %{})
      assert result.content == "Ethereum is a decentralized smart contract platform."
      assert result.model == "openai/gpt-4o-mini"
      assert result.usage["prompt_tokens"] == 15
    end
  end

  describe "ModelRoutePrism" do
    test "routes to smartest model and provides fallback chain" do
      inputs = %{"strategy" => "smartest"}
      assert {:ok, result} = ModelRoutePrism.handler(inputs, %{})
      assert result.selected_model == "anthropic/claude-3.5-sonnet"
      assert is_list(result.fallback_chain)
      assert result.context_length >= 100_000
    end

    test "routes to cheapest model" do
      inputs = %{"strategy" => "cheapest"}
      assert {:ok, result} = ModelRoutePrism.handler(inputs, %{})
      assert result.selected_model == "deepseek/deepseek-chat"
    end

    test "routes to free tier model" do
      inputs = %{"strategy" => "free"}
      assert {:ok, result} = ModelRoutePrism.handler(inputs, %{})
      assert result.selected_model == "meta-llama/llama-3.1-8b-instruct:free"
    end
  end

  describe "CostPrism" do
    test "calculates cost within budget limit" do
      inputs = %{
        "model" => "anthropic/claude-3.5-sonnet",
        "prompt_tokens" => 5_000,
        "completion_tokens" => 1_000,
        "budget_limit" => 1.00
      }

      assert {:ok, result} = CostPrism.handler(inputs, %{})
      assert result.budget_exceeded == false
      assert result.total_cost > 0.0
      assert result.remaining_budget > 0.9
    end

    test "flags when budget limit is exceeded" do
      inputs = %{
        "model" => "anthropic/claude-3.5-sonnet",
        "prompt_tokens" => 500_000,
        "completion_tokens" => 100_000,
        "budget_limit" => 0.50
      }

      assert {:ok, result} = CostPrism.handler(inputs, %{})
      assert result.budget_exceeded == true
    end
  end

  describe "KeyLimitsPrism" do
    test "queries key quotas and verifies sufficiency" do
      Req.Test.stub(KeyLimits, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{
            "label" => "Team API Key",
            "usage" => 5.0,
            "limit" => 100.0,
            "is_free_tier" => false
          }
        })
      end)

      # We pass api_key
      inputs = %{"api_key" => "key-team", "estimated_cost" => 10.0}

      # Test get_key_info directly or with mock
      assert {:ok, info} = KeyLimits.get_key_info("key-team", plug: {Req.Test, KeyLimits})
      assert info.credits_remaining == 95.0
      assert KeyLimits.has_sufficient_credits?(info, 10.0) == true
    end
  end

  describe "FallbackPrism" do
    test "succeeds on first model attempt" do
      Req.Test.stub(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "fb-1",
          "model" => "anthropic/claude-3.5-sonnet",
          "choices" => [
            %{"finish_reason" => "stop", "message" => %{"role" => "assistant", "content" => "Success"}}
          ]
        })
      end)

      inputs = %{
        "prompt" => "Test fallback",
        "models" => ["anthropic/claude-3.5-sonnet", "openai/gpt-4o-mini"],
        "api_key" => "sk-test"
      }

      assert {:ok, result} = FallbackPrism.handler(inputs, %{})
      assert result.content == "Success"
      assert result.attempts == 1
    end

    test "cascades to second model when first fails" do
      attempt_count = :counters.new(1, [:atomics])

      Req.Test.stub(OpenRouter, fn conn ->
        idx = :counters.get(attempt_count, 1)
        :counters.add(attempt_count, 1, 1)

        if idx == 0 do
          conn
          |> Plug.Conn.put_status(429)
          |> Req.Test.json(%{"error" => "Rate limit exceeded"})
        else
          Req.Test.json(conn, %{
            "id" => "fb-2",
            "model" => "openai/gpt-4o-mini",
            "choices" => [
              %{"finish_reason" => "stop", "message" => %{"role" => "assistant", "content" => "Fallback Success"}}
            ]
          })
        end
      end)

      inputs = %{
        "prompt" => "Test fallback cascade",
        "models" => ["anthropic/claude-3.5-sonnet", "openai/gpt-4o-mini"],
        "api_key" => "sk-test"
      }

      assert {:ok, result} = FallbackPrism.handler(inputs, %{})
      assert result.content == "Fallback Success"
      assert result.model_used == "openai/gpt-4o-mini"
      assert result.attempts == 2
    end
  end
end
