defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
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
    test "converts a beam to an Ollama function" do
      beam = TestBeam.view()

      function = Ollama.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestBeam",
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

    test "converts a prism to an Ollama function" do
      prism = TestPrism.view()

      function = Ollama.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestPrism",
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

    test "converts a lens to an Ollama function" do
      lens = TestLens.view()

      function = Ollama.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestLens",
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
        model: "llama3"
      }

      beam = TestBeam.view()

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3"
        assert decoded_body["stream"] == false

        assert [%{"role" => "user", "content" => "test prompt"}] =
                 decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OllamaTest_TestBeam"

        Req.Test.json(conn, %{
          "model" => "llama3",
          "created_at" => "2024-01-01T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "Test response"})
          },
          "done" => true,
          "prompt_eval_count" => 10,
          "eval_count" => 20
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "llama3",
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
              }} = Ollama.call("test prompt", [beam], config)
    end

    test "handles tool call responses with successful tool call (prism)" do
      config = %{
        model: "llama3"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3",
          "created_at" => "2024-01-01T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "#{TestPrism}",
                  "arguments" => %{"value" => "success"}
                }
              }
            ]
          },
          "done" => true,
          "prompt_eval_count" => 10,
          "eval_count" => 5
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: nil,
                  finish_reason: "stop",
                  model: "llama3",
                  tool_calls: [
                    %{
                      "function" => %{
                        "arguments" => ~s({"value":"success"}),
                        "name" => "Elixir.Lux.LLM.OllamaTest.TestPrism"
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
              }} = Ollama.call("test prompt", [TestPrism], config)
    end

    test "handles API error responses" do
      config = %{
        model: "llama3"
      }

      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "model 'nonexistent' not found"}))
      end)

      assert {:error, {404, "model 'nonexistent' not found"}} =
               Ollama.call("test prompt", [], config)
    end

    test "includes Ollama specific parameters in the request" do
      config = %{
        model: "llama3",
        temperature: 0.5,
        top_p: 0.8,
        top_k: 30,
        num_ctx: 8192,
        keep_alive: "10m"
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["options"]["temperature"] == 0.5
        assert decoded_body["options"]["top_p"] == 0.8
        assert decoded_body["options"]["top_k"] == 30
        assert decoded_body["options"]["num_ctx"] == 8192
        assert decoded_body["keep_alive"] == "10m"

        Req.Test.json(conn, %{
          "model" => "llama3",
          "created_at" => "2024-01-01T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "Test response"})
          },
          "done" => true,
          "prompt_eval_count" => 10,
          "eval_count" => 20
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], config)
    end

    test "sets json format when json_response is true" do
      config = %{
        model: "llama3",
        json_response: true
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["format"] == "json"

        Req.Test.json(conn, %{
          "model" => "llama3",
          "created_at" => "2024-01-01T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "ok"})
          },
          "done" => true
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], config)
    end
  end
end
