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
                     }
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct API call using OpenAI-compatible formatting" do
      config = %{
        endpoint: "http://localhost:11434/v1/chat/completions",
        model: "llama3"
      }

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]

        Req.Test.json(conn, %{
          "model" => "llama3",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test OpenAI format response"})
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
                  content: %{"result" => "Test OpenAI format response"},
                  finish_reason: "stop",
                  model: "llama3",
                  tool_calls: nil,
                  tool_calls_results: nil
                }
              }} = Ollama.call("test prompt", [], config)
    end

    test "makes correct API call using native Ollama formatting" do
      config = %{
        endpoint: "http://localhost:11434/api/chat",
        model: "llama3"
      }

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3"

        Req.Test.json(conn, %{
          "model" => "llama3",
          "created_at" => "2024-08-04T12:00:00.000000Z",
          "message" => %{
            "role" => "assistant",
            "content" => ~s({"result": "Test native format response"})
          },
          "done" => true
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test native format response"},
                  finish_reason: "stop",
                  model: "llama3",
                  tool_calls: nil,
                  tool_calls_results: nil
                }
              }} = Ollama.call("test prompt", [], config)
    end
  end
end
