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
        type: :object,
        properties: %{
          location: %{type: :string, description: "City name"}
        },
        required: [:location]
      }

    def after_focus(data), do: data
  end

  # ─── Chat Completion Tests ──────────────────────────────────────────────

  describe "call/3" do
    test "successfully calls Ollama with basic prompt" do
      Req.Test.stub(Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "llama3.2"
        assert decoded["stream"] == false
        assert length(decoded["messages"]) > 0

        Req.Test.json(conn, %{
          "id" => "chatcmpl-ollama-1",
          "object" => "chat.completion",
          "created" => 1_234_567_890,
          "model" => "llama3.2",
          "choices" => [
            %{
              "index" => 0,
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"answer": "Hello from Ollama!"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 20,
            "total_tokens" => 30
          }
        })
      end)

      assert {:ok, %Signal{schema_id: ResponseSignal}} =
               Ollama.call("Hello!", [], %{model: "llama3.2"})
    end

    test "successfully calls Ollama with tools" do
      Req.Test.stub(Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["tools"] != nil
        assert length(decoded["tools"]) == 3

        Req.Test.json(conn, %{
          "id" => "chatcmpl-ollama-2",
          "object" => "chat.completion",
          "created" => 1_234_567_890,
          "model" => "llama3.2",
          "choices" => [
            %{
              "index" => 0,
              "message" => %{
                "role" => "assistant",
                "content" => nil,
                "tool_calls" => [
                  %{
                    "id" => "call_1",
                    "type" => "function",
                    "function" => %{
                      "name" => "Lux_LLM_OllamaTest_TestPrism",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 50,
            "completion_tokens" => 30,
            "total_tokens" => 80
          }
        })
      end)

      assert {:ok, %Signal{schema_id: ResponseSignal}} =
               Ollama.call(
                 "Use the test prism",
                 [TestPrism, TestBeam, TestLens],
                 %{model: "llama3.2"}
               )
    end

    test "handles connection refused" do
      Req.Test.stub(Ollama, fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      # Test with actual connection refused by using invalid endpoint
      result = Ollama.call("Hello!", [], %{
        endpoint: "http://localhost:99999",
        model: "llama3.2",
        receive_timeout: 1000
      })

      assert {:error, _} = result
    end

    test "handles error response from Ollama" do
      Req.Test.stub(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => %{"message" => "model 'nonexistent' not found"}
        }))
      end)

      assert {:error, {404, "model 'nonexistent' not found"}} =
               Ollama.call("Hello!", [], %{model: "nonexistent"})
    end

    test "sends Ollama-specific options when configured" do
      Req.Test.stub(Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["options"]["seed"] == 42
        assert decoded["options"]["num_ctx"] == 4096
        assert decoded["options"]["top_k"] == 40

        Req.Test.json(conn, %{
          "id" => "chatcmpl-ollama-3",
          "object" => "chat.completion",
          "created" => 1_234_567_890,
          "model" => "llama3.2",
          "choices" => [
            %{
              "index" => 0,
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"result": "with options"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 10, "total_tokens" => 20}
        })
      end)

      assert {:ok, %Signal{schema_id: ResponseSignal}} =
               Ollama.call("Test options", [], %{
                 model: "llama3.2",
                 seed: 42,
                 num_ctx: 4096,
                 top_k: 40
               })
    end

    test "handles plain text response when json_response is false" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "id" => "chatcmpl-ollama-4",
          "object" => "chat.completion",
          "created" => 1_234_567_890,
          "model" => "llama3.2",
          "choices" => [
            %{
              "index" => 0,
              "message" => %{
                "role" => "assistant",
                "content" => "This is plain text."
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{schema_id: ResponseSignal}} =
               Ollama.call("Give me plain text", [], %{
                 model: "llama3.2",
                 json_response: false
               })
    end
  end

  # ─── Model Management Tests ─────────────────────────────────────────────

  describe "list_models/1" do
    test "lists available models" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{
              "name" => "llama3.2:latest",
              "size" => 2_000_000_000,
              "digest" => "abc123",
              "modified_at" => "2026-01-01T00:00:00Z"
            },
            %{
              "name" => "mistral:latest",
              "size" => 4_000_000_000,
              "digest" => "def456",
              "modified_at" => "2026-01-01T00:00:00Z"
            }
          ]
        })
      end)

      assert {:ok, models} = Ollama.list_models()
      assert length(models) == 2
      assert Enum.any?(models, &(&1["name"] == "llama3.2:latest"))
    end
  end

  describe "pull_model/2" do
    test "pulls a model successfully" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert :ok = Ollama.pull_model("llama3.2")
    end
  end

  describe "delete_model/2" do
    test "deletes a model successfully" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{"status" => "deleted"})
      end)

      assert :ok = Ollama.delete_model("old-model")
    end
  end

  describe "show_model/2" do
    test "shows model details" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "modelfile" => "FROM llama3.2",
          "parameters" => "temperature 0.7",
          "template" => "{{ .System }}",
          "details" => %{
            "format" => "gguf",
            "family" => "llama",
            "parameter_size" => "8B"
          }
        })
      end)

      assert {:ok, details} = Ollama.show_model("llama3.2")
      assert details["modelfile"] =~ "llama3.2"
    end
  end

  describe "health_check/1" do
    test "checks Ollama health" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{"version" => "0.5.4"})
      end)

      assert {:ok, %{"version" => "0.5.4"}} = Ollama.health_check()
    end
  end
end
