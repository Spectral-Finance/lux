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
      name: "TestLens",
      description: "Gets test data",
      schema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Search query"}
        }
      }
  end

  setup do
    OpenRouter.clear_cost_tracking()
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "makes successful API call and returns Signal with ResponseSignal schema" do
      config = %{model: "meta-llama/llama-3.3-70b-instruct:free"}

      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "https://openrouter.ai/api/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test-key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "meta-llama/llama-3.3-70b-instruct:free"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]
        assert decoded_body["temperature"] == 0.7

        # No tools sent when tools list is empty
        refute Map.has_key?(decoded_body, :tools)

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Hello from OpenRouter!",
                "tool_calls" => nil
              },
              "finish_reason" => "stop",
              "model" => "meta-llama/llama-3.3-70b-instruct:free"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 5,
            "completion_tokens" => 10,
            "total_tokens" => 15
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: "Hello from OpenRouter!",
                  finish_reason: "stop",
                  model: "meta-llama/llama-3.3-70b-instruct:free",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{
                  usage: %{
                    input_tokens: 5,
                    output_tokens: 10,
                    cost: _
                  },
                  provider: :openrouter
                }
              }} = OpenRouter.call("test prompt", [], config)
    end

    test "raises when API key is not configured" do
      System.delete_env("OPENROUTER_API_KEY")
      assert {:error, msg} = OpenRouter.call("test", [], %{})
      assert String.contains?(msg, "OPENROUTER_API_KEY")
    end

    test "handles rate limiting with retry" do
      config = %{model: "test-model"}

      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      call_count = {:counter, 0}

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # Check if this is a rate limit retry by looking at the body
        case elem(call_count, 1) do
          0 ->
            :erlang.set_element(1, call_count, 1)
            {:ok, %Plug.Conn{status: 429, resp_body: %{"error" => %{"message" => "Rate limited"}}}}

          _ ->
            Req.Test.json(conn, %{
              "choices" => [
                %{
                  "message" => %{"content" => "retry succeeded", "tool_calls" => nil},
                  "finish_reason" => "stop",
                  "model" => "test-model"
                }
              ],
              "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5}
            })
        end
      end)

      assert {:ok, %Signal{payload: %{content: "retry succeeded"}}} =
               OpenRouter.call("retry test", [], config)
    end

    test "handles tool calls from LLM response" do
      config = %{model: "test-model"}

      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" => nil,
                "tool_calls" => [
                  %{
                    "type" => "function",
                    "function" => %{
                      "name" => "Elixir.Lux.LLM.OpenRouterTest.TestPrism",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls",
              "model" => "test-model"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 0}
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: nil,
                  finish_reason: "tool_calls",
                  tool_calls: [_],
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = OpenRouter.call("use tool", [TestPrism], config)
    end

    test "passes tools to API request" do
      config = %{model: "test-model"}

      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      beam = TestBeam.view()

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OpenRouterTest_TestBeam"
        assert tool["function"]["parameters"]["type"] == :object

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{"content" => "tool response", "tool_calls" => nil},
              "finish_reason" => "stop",
              "model" => "test-model"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
        })
      end)

      assert {:ok, %Signal{payload: %{content: "tool response"}}} =
               OpenRouter.call("use tool", [beam], config)
    end

    test "tracks costs with actual token usage" do
      config = %{model: "anthropic/claude-3.5-sonnet"}

      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{"content" => "ok", "tool_calls" => nil},
              "finish_reason" => "stop",
              "model" => "anthropic/claude-3.5-sonnet"
            }
          ],
          "usage" => %{"prompt_tokens" => 100, "completion_tokens" => 200}
        })
      end)

      assert {:ok, _} = OpenRouter.call("cost test", [], config)

      costs = OpenRouter.cost_tracking()
      assert length(costs) == 1
      assert costs |> Enum.at(0) |> Map.get(:input_tokens) == 100
      assert costs |> Enum.at(0) |> Map.get(:output_tokens) == 200
    end
  end

  describe "cost_tracking/0" do
    test "returns empty list initially" do
      assert OpenRouter.cost_tracking() == []
    end

    test "clears tracking data" do
      OpenRouter.record_cost("test", 10, 20, 0.001)
      assert length(OpenRouter.cost_tracking()) == 1
      OpenRouter.clear_cost_tracking()
      assert OpenRouter.cost_tracking() == []
    end
  end

  describe "tool_to_function/1" do
    test "converts a beam to OpenRouter function format" do
      beam = TestBeam.view()
      function = OpenRouter.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestBeam",
                 description: "A test beam",
                 parameters: %{type: :object, properties: %{value: %{type: :string}}}
               }
             } = function
    end

    test "converts a prism to OpenRouter function format" do
      prism = TestPrism.view()
      function = OpenRouter.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestPrism",
                 description: "A test prism",
                 parameters: %{type: :object, properties: %{value: %{type: :string}}}
               }
             } = function
    end

    test "converts a lens to OpenRouter function format" do
      lens = TestLens.view()
      function = OpenRouter.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestLens",
                 description: "Gets test data",
                 parameters: %{type: "object", properties: %{query: %{type: "string", description: "Search query"}}}
               }
             } = function
    end
  end

  describe "list_models/0" do
    test "returns parsed models from OpenRouter API" do
      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, "openrouter.ai/api/v1/models")

        Req.Test.json(conn, %{
          "data" => [
            %{
              "id" => "anthropic/claude-3.5-sonnet",
              "name" => "Claude 3.5 Sonnet",
              "context_length" => 200000,
              "pricing" => %{"prompt" => "0.003", "completion" => "0.015"},
              "architecture" => %{"modality" => "text->text"}
            }
          ]
        })
      end)

      assert {:ok, [model]} = OpenRouter.list_models()
      assert model.id == "anthropic/claude-3.5-sonnet"
      assert model.context_length == 200000
      assert model.pricing.prompt == "0.003"
    end
  end

  describe "select_model/1" do
    test "selects model matching criteria" do
      System.put_env("OPENROUTER_API_KEY", "test-key")
      on_exit(fn -> System.delete_env("OPENROUTER_API_KEY") end)

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{"id" => "cheap-model", "context_length" => 4000, "pricing" => %{"prompt" => "0.0001"}},
            %{"id" => "expensive-model", "context_length" => 128000, "pricing" => %{"prompt" => "0.003"}},
            %{"id" => "long-context-model", "context_length" => 1000000, "pricing" => %{"prompt" => "0.001"}}
          ]
        })
      end)

      assert {:ok, model_id} = OpenRouter.select_model(min_context: 100000)
      assert model_id in ["expensive-model", "long-context-model"]
    end
  end
end
