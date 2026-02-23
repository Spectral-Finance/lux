defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
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

  defmodule TestLens do
    @moduledoc false
    use Lux.Lens,
      name: "WeatherAPI",
      description: "Gets weather data",
      schema: %{
        type: "object",
        properties: %{
          location: %{
            type: "string",
            description: "City name"
          },
          units: %{
            type: "string",
            description: "Temperature units"
          }
        }
      }
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an OpenRouter function" do
      beam = TestBeam.view()
      function = OpenRouter.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: :object,
                   properties: %{value: %{type: :string}}
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
      lens = TestLens.view()
      function = OpenRouter.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestLens",
                 description: "Gets weather data",
                 parameters: %{
                   type: "object",
                   properties: %{
                     location: %{type: "string", description: "City name"},
                     units: %{type: "string", description: "Temperature units"}
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct API call to OpenRouter endpoint" do
      config = %{
        api_key: "sk-or-test-key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer sk-or-test-key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "openai/gpt-4o-mini"

        assert [%{"role" => "user", "content" => _}] = decoded_body["messages"]

        Req.Test.json(conn, %{
          "id" => "gen-test-123",
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Paris"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 15,
            "completion_tokens" => 5,
            "total_tokens" => 20,
            "cost" => 0.0000038
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Paris"},
                  finish_reason: "stop",
                  model: "openai/gpt-4o-mini"
                },
                metadata: %{
                  total_cost: 0.0000038,
                  usage: %{"total_tokens" => 20}
                }
              }} = OpenRouter.call("What is the capital of France?", [], config)
    end

    test "includes site headers when configured" do
      config = %{
        api_key: "sk-or-test-key",
        model: "anthropic/claude-3-haiku",
        site_url: "https://myapp.com",
        site_name: "My App"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        referer = Plug.Conn.get_req_header(conn, "http-referer")
        title = Plug.Conn.get_req_header(conn, "x-title")

        assert ["https://myapp.com"] = referer
        assert ["My App"] = title

        Req.Test.json(conn, %{
          "model" => "anthropic/claude-3-haiku",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"ok": true})},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"cost" => 0.0000002}
        })
      end)

      assert {:ok, %Signal{}} = OpenRouter.call("Hello", [], config)
    end

    test "handles tool calls with beam" do
      config = %{
        api_key: "sk-or-test-key",
        model: "openai/gpt-4o"
      }

      beam = TestBeam.view()

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OpenRouterTest_TestBeam"

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test response"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"cost" => 0.000025}
        })
      end)

      assert {:ok, %Signal{payload: %{content: %{"result" => "Test response"}}}} =
               OpenRouter.call("test prompt", [beam], config)
    end

    test "handles tool call responses and executes prism" do
      config = %{
        api_key: "sk-or-test-key",
        model: "openai/gpt-4o"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o",
          "choices" => [
            %{
              "message" => %{
                "tool_calls" => [
                  %{
                    "type" => "function",
                    "function" => %{
                      "name" => "#{TestPrism}",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => %{"cost" => 0.000010}
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  finish_reason: "tool_calls",
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = OpenRouter.call("test prompt", [TestPrism], config)
    end

    test "returns error on invalid API key" do
      config = %{
        api_key: "invalid-key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, :invalid_api_key} = OpenRouter.call("test", [], config)
    end

    test "returns error on insufficient credits" do
      config = %{
        api_key: "sk-or-test-key",
        model: "openai/gpt-4o"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(402)
        |> Req.Test.json(%{"error" => %{"message" => "Insufficient credits"}})
      end)

      assert {:error, :insufficient_credits} = OpenRouter.call("test", [], config)
    end

    test "returns error on rate limit" do
      config = %{
        api_key: "sk-or-test-key",
        model: "meta-llama/llama-3.1-70b-instruct"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, :rate_limited} = OpenRouter.call("test", [], config)
    end

    test "routes request with explicit route parameter" do
      config = %{
        api_key: "sk-or-test-key",
        model: "openai/gpt-4o-mini",
        route: "fallback"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["route"] == "fallback"

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"ok": true})},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{}} = OpenRouter.call("test", [], config)
    end
  end

  describe "estimate_cost/3" do
    test "estimates cost for known models" do
      assert {:ok, cost} = OpenRouter.estimate_cost("openai/gpt-4o", 1000, 500)
      assert is_float(cost)
      assert cost > 0
    end

    test "estimates cost for mini model" do
      assert {:ok, cost} = OpenRouter.estimate_cost("openai/gpt-4o-mini", 1000, 500)
      assert is_float(cost)
      # Mini should be cheaper than full gpt-4o
      {:ok, full_cost} = OpenRouter.estimate_cost("openai/gpt-4o", 1000, 500)
      assert cost < full_cost
    end

    test "returns error for unknown model" do
      assert {:error, :unknown_model} =
               OpenRouter.estimate_cost("unknown/model-xyz", 1000, 500)
    end
  end
end
