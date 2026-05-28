defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

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

  describe "call/3" do
    test "makes correct API call and returns structured response" do
      config = %{
        model: "llama3",
        endpoint: "http://localhost:11434/v1/chat/completions"
      }

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "llama3"
        assert decoded["stream"] == false
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded["messages"]

        Req.Test.json(conn, %{
          "id" => "ollama-1",
          "model" => "llama3",
          "created" => 1_700_000_000,
          "choices" => [
            %{
              "message" => %{"content" => ~s({"answer": "42"}), "tool_calls" => nil},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 10}
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"answer" => "42"},
                  finish_reason: "stop",
                  model: "llama3"
                }
              }} = Ollama.call("test prompt", [], config)
    end

    test "returns connection refused error when Ollama is not running" do
      config = %{model: "llama3", endpoint: "http://localhost:11434/v1/chat/completions"}

      Req.Test.expect(Ollama, fn _conn ->
        raise %Req.TransportError{reason: :econnrefused}
      end)

      assert {:error, "Ollama is not running. Start it with: ollama serve"} =
               Ollama.call("test prompt", [], config)
    end

    test "handles tool call responses" do
      config = %{model: "llama3"}

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "id" => "ollama-2",
          "model" => "llama3",
          "created" => 1_700_000_000,
          "choices" => [
            %{
              "message" => %{
                "content" => nil,
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
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{payload: %{finish_reason: "tool_calls"}}} =
               Ollama.call("test prompt", [TestPrism], config)
    end

    test "json_response: true adds format: json to request body" do
      config = %{model: "llama3", json_response: true}

      Req.Test.expect(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["format"] == "json"

        Req.Test.json(conn, %{
          "model" => "llama3",
          "choices" => [%{"message" => %{"content" => "{}", "tool_calls" => nil}, "finish_reason" => "stop"}],
          "usage" => %{}
        })
      end)

      assert {:ok, _} = Ollama.call("prompt", [], config)
    end
  end

  describe "tool_to_function/1" do
    test "converts a prism to a function spec" do
      function = Ollama.tool_to_function(TestPrism)

      assert %{
               type: "function",
               function: %{
                 name: name,
                 description: "A test prism"
               }
             } = function

      assert String.ends_with?(name, "TestPrism")
    end
  end
end
