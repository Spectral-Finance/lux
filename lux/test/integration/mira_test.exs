defmodule Lux.Integration.LLM.MiraTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.LLM.Mira
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  describe "simple text request and response, no tools or structure output" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_mira],
        model: "llama-3.1-8b-instruct",
        temperature: 0.7,
        stream: false
      }

      %{config: config}
    end

    test "it returns a structured response", %{config: config} do
      assert {:ok,
              %Signal{
                id: _,
                metadata: %{
                  id: _,
                  usage: %{
                    "completion_tokens" => _,
                    "prompt_tokens" => _,
                    "total_tokens" => _
                  },
                  created: _,
                  system_fingerprint: _
                },
                payload: %{
                  model: "llama-3.1-8b-instruct",
                  content: content,
                  tool_calls: nil,
                  tool_calls_results: nil,
                  finish_reason: "stop"
                },
                recipient: nil,
                schema_id: ResponseSignal,
                sender: nil,
                timestamp: _
              }} = Mira.call("What is the capital of France?", [], config)

      assert is_binary(content) or is_map(content)
    end
  end

  describe "call/3" do
    test "makes correct API call with tools" do
      config = %{
        api_key: "test_key",
        model: "llama-3.1-8b-instruct"
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

      Req.Test.expect(Mira, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama-3.1-8b-instruct"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "TestBeam"

        # Mira specific parameters
        assert is_float(decoded_body["temperature"])
        assert is_boolean(decoded_body["stream"])

        Req.Test.json(conn, %{
          "model" => "llama-3.1-8b-instruct",
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
                  model: "llama-3.1-8b-instruct",
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
              }} = Mira.call("test prompt", [beam], config)
    end
  end
end 
