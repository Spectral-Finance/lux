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

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an Ollama function" do
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

      function = Ollama.tool_to_function(beam)

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
      lens =
        Lux.Lens.new(
          name: "LocalMetrics",
          description: "Gets local system metrics",
          schema: %{
            type: "object",
            properties: %{
              metric: %{
                type: "string",
                description: "Metric name"
              }
            }
          }
        )

      function = Ollama.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "LocalMetrics",
                 description: "Gets local system metrics",
                 parameters: %{
                   type: "object",
                   properties: %{
                     metric: %{
                       type: "string",
                       description: "Metric name"
                     }
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "successfully makes chat completion and returns ResponseSignal" do
      config = %{
        model: "llama3.2",
        temperature: 0.7
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2"
        assert decoded_body["options"]["temperature"] == 0.7
        assert decoded_body["stream"] == false

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-10-30T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "Ollama local response"})
          },
          "done" => true,
          "done_reason" => "stop",
          "total_duration" => 500_000,
          "prompt_eval_count" => 12,
          "eval_count" => 20
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Ollama local response"},
                  finish_reason: "stop",
                  model: "llama3.2"
                }
              }} = Ollama.call("test prompt", [], config)
    end

    test "handles tool calls with successful prism execution" do
      config = %{
        model: "llama3.2"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-10-30T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => nil,
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
          "done_reason" => "stop"
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: nil,
                  finish_reason: "stop",
                  model: "llama3.2",
                  tool_calls: [
                    %{
                      "function" => %{
                        "name" => "Elixir.Lux.LLM.OllamaTest.TestPrism",
                        "arguments" => %{"value" => "success"}
                      }
                    }
                  ],
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = Ollama.call("test prompt", [TestPrism], config)
    end

    test "handles model not found 404 error cleanly" do
      config = %{model: "nonexistent-model"}

      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"error" => "model 'nonexistent-model' not found"})
      end)

      assert {:error, {:model_not_found, "model 'nonexistent-model' not found"}} =
               Ollama.call("test prompt", [], config)
    end
  end

  describe "model management" do
    test "list_models/1 retrieves model list" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/tags"
        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3.2:latest", "size" => 2000000000},
            %{"name" => "mistral:latest", "size" => 4000000000}
          ]
        })
      end)

      assert {:ok, models} = Ollama.list_models()
      assert length(models) == 2
      assert hd(models)["name"] == "llama3.2:latest"
    end

    test "pull_model/2 sends pull request" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/pull"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["name"] == "llama3.2"
        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, %{"status" => "success"}} = Ollama.pull_model("llama3.2")
    end

    test "delete_model/2 deletes a model" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/delete"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["name"] == "llama3.2"
        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert :ok = Ollama.delete_model("llama3.2")
    end
  end
end
