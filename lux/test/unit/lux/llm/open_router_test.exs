defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
  alias Lux.LLM.OpenRouter.KeyLimits
  alias Lux.LLM.OpenRouter.ModelRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success test"}}
    def handler(%{"value" => "failure"}, _context), do: {:error, "failure test"}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test beam"

    sequence do
      step(:test, TestPrism, %{})
    end
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an OpenRouter function" do
      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{type: "string", description: "Test value"},
              "amount" => %{type: "float", description: "Test amount"}
            }
          }
        )

      function = OpenRouter.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: "object",
                   properties: %{
                     "value" => %{type: "string", description: "Test value"},
                     "amount" => %{type: "float", description: "Test amount"}
                   }
                 }
               }
             } = function
    end

    test "converts a prism to an OpenRouter function" do
      prism = TestPrism.view()
      function = OpenRouter.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestPrism",
                 description: "A test prism",
                 parameters: %{
                   type: :object,
                   properties: %{value: %{type: :string}}
                 }
               }
             } = function
    end

    test "converts a lens to an OpenRouter function" do
      lens =
        Lux.Lens.new(
          name: "CryptoPrice",
          description: "Gets crypto spot price",
          schema: %{
            type: "object",
            properties: %{
              symbol: %{type: "string", description: "Crypto symbol"}
            }
          }
        )

      function = OpenRouter.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "CryptoPrice",
                 description: "Gets crypto spot price",
                 parameters: %{
                   type: "object",
                   properties: %{symbol: %{type: "string", description: "Crypto symbol"}}
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "successfully makes an API call with OpenRouter headers and returns a valid ResponseSignal" do
      Req.Test.stub(OpenRouter, fn conn ->
        # Assert OpenRouter custom headers are present
        assert Plug.Conn.get_req_header(conn, "http-referer") == ["https://lux.agent"]
        assert Plug.Conn.get_req_header(conn, "x-title") == ["Lux Agent"]
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-key"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["model"] == "anthropic/claude-3.5-sonnet"
        assert json["messages"] == [%{"role" => "user", "content" => "Hello OpenRouter"}]

        Req.Test.json(conn, %{
          "id" => "gen-12345",
          "model" => "anthropic/claude-3.5-sonnet",
          "created" => 1718000000,
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Hello! How can I assist you with Lux?"
              }
            }
          ],
          "usage" => %{
            "prompt_tokens" => 20,
            "completion_tokens" => 15,
            "total_tokens" => 35
          }
        })
      end)

      config = %{
        api_key: "test-key",
        model: "anthropic/claude-3.5-sonnet"
      }

      assert {:ok, %Signal{} = signal} = OpenRouter.call("Hello OpenRouter", [], config)
      assert signal.schema_id == ResponseSignal
      assert signal.payload.content == "Hello! How can I assist you with Lux?"
      assert signal.payload.model == "anthropic/claude-3.5-sonnet"
      assert signal.metadata.usage["prompt_tokens"] == 20
      assert signal.metadata.cost_estimate.total_cost > 0.0
    end

    test "handles structured JSON content output" do
      Req.Test.stub(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "gen-struct-1",
          "model" => "openai/gpt-4o",
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"action": "buy", "confidence": 0.95})
              }
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 8}
        })
      end)

      assert {:ok, %Signal{} = signal} =
               OpenRouter.call("Output json", [], %{api_key: "test-key", model: "openai/gpt-4o"})

      assert signal.payload.content == %{"action" => "buy", "confidence" => 0.95}
    end

    test "handles tool calling execution" do
      Req.Test.stub(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "gen-tool-1",
          "model" => "openai/gpt-4o",
          "choices" => [
            %{
              "finish_reason" => "tool_calls",
              "message" => %{
                "role" => "assistant",
                "content" => nil,
                "tool_calls" => [
                  %{
                    "id" => "call_abc123",
                    "type" => "function",
                    "function" => %{
                      "name" => "Lux_LLM_OpenRouterTest_TestPrism",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              }
            }
          ]
        })
      end)

      assert {:ok, %Signal{} = signal} =
               OpenRouter.call("Run tool", [TestPrism], %{api_key: "test-key"})

      assert signal.payload.tool_calls_results == [%{result: "success test"}]
    end

    test "returns error on missing API key" do
      assert {:error, :missing_api_key} =
               OpenRouter.call("Prompt", [], %{api_key: nil})
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => "Invalid API key"})
      end)

      assert {:error, :invalid_api_key} =
               OpenRouter.call("Prompt", [], %{api_key: "invalid-key"})
    end

    test "handles 402 insufficient credits" do
      Req.Test.stub(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(402)
        |> Req.Test.json(%{"error" => "Key has run out of credits"})
      end)

      assert {:error, {:insufficient_credits, _}} =
               OpenRouter.call("Prompt", [], %{api_key: "test-key"})
    end
  end

  describe "KeyLimits" do
    test "fetches and parses key limits and remaining credits" do
      fake_resp = %{
        "data" => %{
          "label" => "Production Lux Key",
          "usage" => 12.45,
          "limit" => 50.0,
          "is_free_tier" => false,
          "rate_limit" => %{
            "requests" => 200,
            "interval" => "10s"
          }
        }
      }

      Req.Test.stub(KeyLimits, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer key-123"]
        Req.Test.json(conn, fake_resp)
      end)

      assert {:ok, %KeyLimits.Info{} = info} =
               KeyLimits.get_key_info("key-123", plug: {Req.Test, KeyLimits})

      assert info.label == "Production Lux Key"
      assert info.usage == 12.45
      assert info.limit == 50.0
      assert info.credits_remaining == 37.55
      assert info.usage_percentage == 24.9
      assert info.is_free_tier == false
      assert info.rate_limit_requests == 200
      assert KeyLimits.has_sufficient_credits?(info, 5.0) == true
      assert KeyLimits.has_sufficient_credits?(info, 40.0) == false
    end
  end

  describe "ModelRouter" do
    test "selects models according to strategy" do
      assert ModelRouter.select_model(strategy: :cheapest) == "deepseek/deepseek-chat"
      assert ModelRouter.select_model(strategy: :fastest) == "google/gemini-2.0-flash"
      assert ModelRouter.select_model(strategy: :free) == "meta-llama/llama-3.1-8b-instruct:free"
      assert ModelRouter.select_model(strategy: :smartest) == "anthropic/claude-3.5-sonnet"
      assert ModelRouter.select_model(strategy: :balanced) == "openai/gpt-4o-mini"
    end

    test "builds fallback chains properly" do
      chain = ModelRouter.build_fallback_chain("anthropic/claude-3.5-sonnet")
      assert hd(chain) == "anthropic/claude-3.5-sonnet"
      assert "openai/gpt-4o" in chain
      assert "openai/gpt-4o-mini" in chain
    end

    test "calculates estimated USD token cost" do
      estimate = ModelRouter.estimate_cost("anthropic/claude-3.5-sonnet", 10_000, 2_000)
      # 10k prompt * $3/1M = $0.03
      # 2k completion * $15/1M = $0.03
      # total = $0.06
      assert estimate.prompt_cost == 0.03
      assert estimate.completion_cost == 0.03
      assert estimate.total_cost == 0.06
    end
  end
end
