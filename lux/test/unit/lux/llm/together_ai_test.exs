defmodule Lux.LLM.TogetherAITest do
  use UnitAPICase, async: true

  alias Lux.LLM.TogetherAI
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
    test "converts a beam to a Together AI function" do
      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              },
              "amount" => %{
                type: "float",
                description: "Test amount"
              }
            }
          }
        )

      function = TogetherAI.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: "object",
                   properties: %{
                     "value" => %{
                       type: "string",
                       description: "Test value"
                     },
                     "amount" => %{
                       type: "float",
                       description: "Test amount"
                     }
                   }
                 }
               }
             } = function
    end

    test "converts a prism to a Together AI function" do
      prism = TestPrism.view()

      function = TogetherAI.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_TogetherAITest_TestPrism",
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

    test "converts a lens to a Together AI function" do
      lens =
        Lux.Lens.new(
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
        )

      function = TogetherAI.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "WeatherAPI",
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
        model: "mistralai/Mistral-7B-Instruct-v0.2"
      }

      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              }
            }
          }
        )

      Req.Test.expect(TogetherAI, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "mistralai/Mistral-7B-Instruct-v0.2"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "TestBeam"

        # Together AI specific parameters
        assert is_float(decoded_body["temperature"])
        assert is_float(decoded_body["top_p"])
        assert is_integer(decoded_body["top_k"])
        assert is_float(decoded_body["repetition_penalty"])

        Req.Test.json(conn, %{
          "model" => "mistralai/Mistral-7B-Instruct-v0.2",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test response"})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "mistralai/Mistral-7B-Instruct-v0.2",
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
                  system_fingerprint: _
                }
              }} = TogetherAI.call("test prompt", [beam], config)
    end

    test "handles tool call responses with successful tool call (prism)" do
      config = %{
        api_key: "test_key",
        model: "mistralai/Mistral-7B-Instruct-v0.2"
      }

      Req.Test.expect(TogetherAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "mistralai/Mistral-7B-Instruct-v0.2",
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
                  model: "mistralai/Mistral-7B-Instruct-v0.2",
                  tool_calls: [
                    %{
                      "function" => %{
                        "arguments" => ~s({"value": "success"}),
                        "name" => "Elixir.Lux.LLM.TogetherAITest.TestPrism"
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
              }} = TogetherAI.call("test prompt", [TestPrism], config)
    end

    test "includes Together AI specific parameters in the request" do
      config = %{
        api_key: "test_key",
        model: "mistralai/Mistral-7B-Instruct-v0.2",
        temperature: 0.8,
        top_p: 0.9,
        top_k: 40,
        repetition_penalty: 1.1,
        stop: ["END"]
      }

      Req.Test.expect(TogetherAI, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["temperature"] == 0.8
        assert decoded_body["top_p"] == 0.9
        assert decoded_body["top_k"] == 40
        assert decoded_body["repetition_penalty"] == 1.1
        assert decoded_body["stop"] == ["END"]

        Req.Test.json(conn, %{
          "model" => "mistralai/Mistral-7B-Instruct-v0.2",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test response"})
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok, _} = TogetherAI.call("test prompt", [], config)
    end
  end
end
