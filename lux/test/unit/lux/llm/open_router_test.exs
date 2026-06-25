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
                   properties: %{
                     value: %{type: :string}
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
                   properties: %{
                     value: %{type: :string}
                   }
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
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct API call with tools" do
      config = %{
        api_key: "test_key",
        model: "anthropic/claude-3.5-sonnet"
      }

      beam = TestBeam.view()

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        referer = Plug.Conn.get_req_header(conn, "http-referer")
        assert ["https://github.com/Spectral-Finance/lux"] = referer

        title = Plug.Conn.get_req_header(conn, "x-title")
        assert ["Lux LLM Agent"] = title

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "anthropic/claude-3.5-sonnet"

        assert [%{"role" => "user", "content" => "test prompt" <> "\nReply in json format"}] =
                 decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OpenRouterTest_TestBeam"

        Req.Test.json(conn, %{
          "model" => "anthropic/claude-3.5-sonnet",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test response"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 100,
            "completion_tokens" => 50
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "anthropic/claude-3.5-sonnet",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                sender: nil,
                recipient: nil,
                timestamp: _,
                metadata: %{
                  id: _,
                  usage: _,
                  created: _,
                  system_fingerprint: _,
                  provider: _
                }
              }} = OpenRouter.call("test prompt", [beam], config)
    end

    test "handles tool call responses with successful tool call (prism)" do
      config = %{
        api_key: "test_key",
        model: "anthropic/claude-3.5-sonnet"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "model" => "anthropic/claude-3.5-sonnet",
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
          ]
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: nil,
                  finish_reason: "tool_calls",
                  model: "anthropic/claude-3.5-sonnet",
                  tool_calls: [
                    %{
                      "function" => %{
                        "arguments" => ~s({"value": "success"}),
                        "name" => "Elixir.Lux.LLM.OpenRouterTest.TestPrism"
                      },
                      "type" => "function"
                    }
                  ],
                  tool_calls_results: [%{result: "success test"}]
                },
                sender: nil,
                recipient: nil,
                timestamp: _,
                metadata: _
              }} = OpenRouter.call("test prompt", [TestPrism], config)
    end

    test "handles invalid API key" do
      config = %{
        api_key: "bad_key",
        model: "anthropic/claude-3.5-sonnet"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "error" => %{
            "message" => "Invalid API key"
          }
        }))
      end)

      result = OpenRouter.call("test prompt", [], config)
      assert {:error, :invalid_api_key} = result
    end

    test "handles API errors" do
      config = %{
        api_key: "test_key",
        model: "anthropic/claude-3.5-sonnet"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{
            "message" => "Bad request"
          }
        }))
      end)

      result = OpenRouter.call("test prompt", [], config)
      assert {:error, {400, "Bad request"}} = result
    end

    test "returns cost in payload when usage includes total_cost" do
      config = %{
        api_key: "test_key",
        model: "anthropic/claude-3.5-sonnet"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "model" => "anthropic/claude-3.5-sonnet",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "cost test"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "total_cost" => 0.0025,
            "prompt_tokens" => 100,
            "completion_tokens" => 50
          }
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  cost: 0.0025
                }
              }} = OpenRouter.call("test prompt", [], config)
    end

    test "calculates cost from token counts when total_cost is not present" do
      config = %{
        api_key: "test_key",
        model: "anthropic/claude-3.5-sonnet"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "model" => "anthropic/claude-3.5-sonnet",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "calculated cost"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 1000,
            "completion_tokens" => 500
          }
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  cost: cost
                }
              }} = OpenRouter.call("test prompt", [], config)

      # claude-3.5-sonnet: $3/M input, $15/M output
      # 1000 * 3/1_000_000 + 500 * 15/1_000_000 = 0.003 + 0.0075 = 0.0105
      assert cost == 0.0105
    end
  end

  describe "calculate_cost/3" do
    test "calculates cost for claude-3.5-sonnet" do
      cost = OpenRouter.calculate_cost("anthropic/claude-3.5-sonnet", 1000, 500)
      assert cost == 0.0105
    end

    test "calculates cost for gpt-4o" do
      cost = OpenRouter.calculate_cost("openai/gpt-4o", 1000, 500)
      # $5/M input, $15/M output
      assert cost == 0.0125
    end

    test "calculates cost for gpt-4o-mini" do
      cost = OpenRouter.calculate_cost("openai/gpt-4o-mini", 1000, 500)
      # $0.15/M input, $0.60/M output
      assert cost == 0.0005
    end

    test "calculates cost for unknown model returns zero" do
      cost = OpenRouter.calculate_cost("unknown/model", 1000, 500)
      assert cost == 0.0
    end
  end
end
