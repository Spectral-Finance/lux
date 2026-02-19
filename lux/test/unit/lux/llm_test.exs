defmodule Lux.LLMTest do
  use UnitAPICase, async: false

  alias Lux.LLM
  alias Lux.LLM.{CostTracker, PerformanceMonitor}

  setup do
    CostTracker.reset()
    PerformanceMonitor.reset()
    :ok
  end

  describe "call/3" do
    test "calls default provider" do
      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "hello"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 5,
            "total_tokens" => 15
          }
        })
      end)

      result = LLM.call("test", [], %{model: "gpt-4o", api_key: "test"})
      assert {:ok, _response} = result
    end

    test "routes to specified provider" do
      Req.Test.expect(Lux.LLM.Anthropic, fn conn ->
        Req.Test.json(conn, %{
          "id" => "msg_123",
          "type" => "message",
          "role" => "assistant",
          "content" => [
            %{"type" => "text", "text" => "Hello from Anthropic"}
          ],
          "model" => "claude-3-opus-20240229",
          "stop_reason" => "end_turn"
        })
      end)

      result =
        LLM.call("test", [], %{
          provider: :anthropic,
          model: "claude-3-opus-20240229",
          api_key: "test"
        })

      assert {:ok, _response} = result
    end

    test "records performance metrics after call" do
      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"ok": true})},
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      LLM.call("test", [], %{model: "gpt-4o", api_key: "test"})

      analytics = PerformanceMonitor.analytics()
      assert analytics.total_requests >= 1
    end

    test "handles keyword list config" do
      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"ok": true})},
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      result = LLM.call("test", [], [model: "gpt-4o", api_key: "test"])
      assert {:ok, _} = result
    end
  end

  describe "call_with_fallback/3" do
    test "uses explicit fallback chain" do
      Req.Test.expect(Lux.LLM.OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4o",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"result": "from openai"})},
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      result =
        LLM.call_with_fallback("test", [], %{
          fallback_chain: [
            {:openai, %{model: "gpt-4o", api_key: "test"}}
          ]
        })

      assert {:ok, _response, :openai} = result
    end
  end

  describe "list_providers/0" do
    test "returns registered providers" do
      providers = LLM.list_providers()
      assert is_list(providers)
      names = Enum.map(providers, fn {name, _mod, _prio} -> name end)
      assert :openai in names
    end
  end

  describe "cost_summary/1" do
    test "returns cost summary" do
      CostTracker.record(:openai, "gpt-4o", %{
        input_tokens: 100,
        output_tokens: 50,
        cost: 0.005
      })

      summary = LLM.cost_summary()
      assert summary.total_requests == 1
    end
  end

  describe "performance_analytics/1" do
    test "returns performance analytics" do
      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 200,
        status: :ok,
        model: "gpt-4o"
      })

      analytics = LLM.performance_analytics()
      assert analytics.total_requests == 1
    end
  end
end
