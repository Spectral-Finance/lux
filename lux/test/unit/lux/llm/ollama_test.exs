defmodule Lux.LLM.OllamaTest do
  use Lux.Test.Support.Case, async: true

  alias Lux.LLM.Ollama

  describe "Ollama /chat/completions" do
    @tag :external
    test "returns a response for a simple prompt" do
      assert {:ok, signal} =
               Ollama.call("What is the capital of France?", [], %{model: "llama3.2"})

      assert signal.schema_id == "response"
    end

    @tag :external
    test "handles unauthorized access" do
      assert {:error, {:error, _}} =
               Ollama.call("test", [], %{api_key: "invalid", endpoint: "http://localhost:9999/v1/chat/completions"})
    end
  end
end

  describe "call/3" do
    test "makes correct API call" do
      config = %{
        api_key: "test_key",
        model: "sonar-pro"
      }

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "sonar-pro"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]

        Req.Test.json(conn, %{
          "id" => "test-id-123",
          "model" => "sonar-pro",
          "created" => 1_720_000_000,
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 20, "total_tokens" => 30},
          "citations" => ["https://example.com"],
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"answer": "Test response"})
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
                  content: %{"answer" => "Test response"},
                  finish_reason: "stop",
                  model: "sonar-pro",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                sender: nil,
                recipient: nil,
                timestamp: _,
                metadata: %{
                  id: "test-id-123",
                  usage: %{"prompt_tokens" => 10, "completion_tokens" => 20, "total_tokens" => 30},
                  created: 1_720_000_000,
                  citations: ["https://example.com"]
                }
              }} = Perplexity.call("test prompt", [], config)
    end

    test "handles non-JSON text content" do
      config = %{
        api_key: "test_key",
        model: "sonar-pro"
      }

      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "id" => "test-id-456",
          "model" => "sonar-pro",
          "created" => 1_720_000_001,
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 15, "total_tokens" => 20},
          "choices" => [
            %{
              "message" => %{
                "content" => "Perplexity is a search engine that uses AI."
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
                  content: %{"text" => "Perplexity is a search engine that uses AI."},
                  finish_reason: "stop",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{
                  id: "test-id-456"
                }
              }} = Perplexity.call("What is Perplexity?", [], config)
    end

    test "returns error on 401" do
      config = %{
        api_key: "bad_key",
        model: "sonar-pro"
      }

      Req.Test.expect(Perplexity, fn conn ->
        Plug.Conn.send_resp(conn, 401, ~s({"error": {"message": "Invalid API key"}}))
      end)

      assert {:error, :invalid_api_key} = Perplexity.call("test", [], config)
    end
  end
end
