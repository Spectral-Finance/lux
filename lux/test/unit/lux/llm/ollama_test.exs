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
          }
        }
      }
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an Ollama tool" do
      function = Ollama.tool_to_function(TestBeam.view())

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

    test "converts a prism to an Ollama tool" do
      function = Ollama.tool_to_function(TestPrism.view())

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestPrism",
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

    test "converts a lens to an Ollama tool" do
      function = Ollama.tool_to_function(TestLens.view())

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
                     }
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct local chat API call with tools and resource options" do
      config = %{
        model: "llama3.2",
        temperature: 0.2,
        top_p: 0.8,
        max_tokens: 128,
        num_ctx: 4096,
        num_thread: 4,
        keep_alive: "10m"
      }

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2"
        assert decoded_body["stream"] == false
        assert decoded_body["keep_alive"] == "10m"

        assert [
                 %{"role" => "user", "content" => "test prompt"},
                 %{"role" => "system", "content" => "Reply in JSON format."}
               ] = decoded_body["messages"]

        assert decoded_body["format"] == "json"
        assert decoded_body["options"]["temperature"] == 0.2
        assert decoded_body["options"]["top_p"] == 0.8
        assert decoded_body["options"]["num_predict"] == 128
        assert decoded_body["options"]["num_ctx"] == 4096
        assert decoded_body["options"]["num_thread"] == 4

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_OllamaTest_TestBeam"

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-06-23T09:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result":"Test response"})
          },
          "done" => true,
          "done_reason" => "stop",
          "prompt_eval_count" => 10,
          "eval_count" => 20,
          "eval_duration" => 2_000_000_000
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "llama3.2",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{
                  usage: %{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30},
                  performance: %{tokens_per_second: 10.0}
                }
              }} = Ollama.call("test prompt", [TestBeam], config)
    end

    test "supports schema formatted JSON responses" do
      schema = %{
        type: "object",
        properties: %{
          result: %{type: "string"}
        },
        required: ["result"]
      }

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["format"] == %{
                 "type" => "object",
                 "properties" => %{"result" => %{"type" => "string"}},
                 "required" => ["result"]
               }

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{"content" => ~s({"result":"ok"})},
          "done" => true
        })
      end)

      assert {:ok, _} = Ollama.call("test prompt", [], %{json_schema: schema})
    end

    test "handles tool call responses with map arguments" do
      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
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
          "done_reason" => "tool_calls"
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = Ollama.call("test prompt", [TestPrism], %{model: "llama3.2"})
    end

    test "handles Ollama API errors" do
      Req.Test.expect(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "model not found"}))
      end)

      assert {:error, {404, "model not found"}} =
               Ollama.call("test prompt", [], %{model: "missing-model"})
    end
  end

  describe "model management" do
    test "lists locally cached models" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/tags"

        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3.2", "model" => "llama3.2"}
          ]
        })
      end)

      assert {:ok, [%{"name" => "llama3.2"}]} = Ollama.list_models()
    end

    test "detects whether a model is locally cached" do
      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3.2", "model" => "llama3.2"}
          ]
        })
      end)

      assert {:ok, true} = Ollama.model_available?("llama3.2")
    end

    test "pulls a missing model" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2"
        assert decoded_body["stream"] == false

        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, %{"status" => "success"}} = Ollama.pull_model("llama3.2")
    end

    test "uses cached model without pulling" do
      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3.2", "model" => "llama3.2"}
          ]
        })
      end)

      assert {:ok, :cached} = Ollama.ensure_model("llama3.2")
    end

    test "loads and unloads models through keep_alive" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2"
        assert decoded_body["messages"] == []
        assert decoded_body["keep_alive"] == "10m"

        Req.Test.json(conn, %{"done" => true})
      end)

      assert {:ok, _} = Ollama.load_model("llama3.2", %{keep_alive: "10m"})

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3.2"
        assert decoded_body["messages"] == []
        assert decoded_body["keep_alive"] == 0

        Req.Test.json(conn, %{"done" => true})
      end)

      assert {:ok, _} = Ollama.unload_model("llama3.2")
    end
  end
end
