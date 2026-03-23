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
                     value: %{
                       type: :string
                     }
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
        model: "openai/gpt-4o-mini"
      }

      beam = TestBeam.view()

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "openai/gpt-4o-mini"

        assert [%{"role" => "user", "content" => "test prompt" <> "\n Reply in json format"}] =
                 decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OpenRouterTest_TestBeam"

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test response"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 20,
            "total_tokens" => 30,
            "cost" => 0.00015
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "openai/gpt-4o-mini",
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
                  cost: _
                }
              }} = OpenRouter.call("test prompt", [beam], config)
    end

    test "handles tool call responses with successful tool call (prism)" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
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
                  model: "openai/gpt-4o-mini",
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

    test "includes cost in response metadata" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
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
            "total_tokens" => 15,
            "cost" => 0.00042
          }
        })
      end)

      assert {:ok,
              %Signal{
                metadata: %{
                  cost: 0.00042,
                  usage: %{
                    "prompt_tokens" => 10,
                    "completion_tokens" => 5,
                    "total_tokens" => 15,
                    "cost" => 0.00042
                  }
                }
              }} = OpenRouter.call("test prompt", [], config)
    end

    test "sends transforms and route in request body" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini",
        transforms: ["middle-out"],
        route: "fallback"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["transforms"] == ["middle-out"]
        assert decoded_body["route"] == "fallback"

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"ok": true})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok, %Signal{}} = OpenRouter.call("test prompt", [], config)
    end

    test "sends provider preferences in request body" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini",
        provider: %{order: ["OpenAI", "Anthropic"]}
      }

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["provider"] == %{"order" => ["OpenAI", "Anthropic"]}

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"ok": true})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok, %Signal{}} = OpenRouter.call("test prompt", [], config)
    end

    test "sends HTTP-Referer and X-Title headers" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini",
        http_referer: "https://example.com",
        x_title: "My App"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        referer = Plug.Conn.get_req_header(conn, "http-referer")
        assert ["https://example.com"] = referer

        x_title = Plug.Conn.get_req_header(conn, "x-title")
        assert ["My App"] = x_title

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"ok": true})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok, %Signal{}} = OpenRouter.call("test prompt", [], config)
    end

    test "handles structured JSON output with json_schema" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini",
        json_response: true,
        json_schema: %{
          name: "test_schema",
          schema: %{
            type: "object",
            properties: %{
              name: %{type: "string"},
              age: %{type: "integer"}
            }
          }
        }
      }

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["response_format"]["type"] == "json_schema"
        assert decoded_body["response_format"]["json_schema"]["name"] == "test_schema"

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"name": "Alice", "age": 30})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"name" => "Alice", "age" => 30}
                }
              }} = OpenRouter.call("test prompt", [], config)
    end

    test "handles 401 unauthorized error" do
      config = %{
        api_key: "invalid_key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, :invalid_api_key} = OpenRouter.call("test prompt", [], config)
    end

    test "handles 429 rate limit error" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, {429, "Rate limit exceeded"}} = OpenRouter.call("test prompt", [], config)
    end

    test "handles network errors" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, "OpenRouter API error: " <> _} = OpenRouter.call("test prompt", [], config)
    end
  end
end
