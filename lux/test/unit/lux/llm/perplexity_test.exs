defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
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
    test "converts a beam to a Perplexity function" do
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

      function = Perplexity.tool_to_function(beam)

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
    test "makes correct API call with tools" do
      config = %{
        api_key: "test_key",
        model: "sonar-reasoning"
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

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "sonar-reasoning"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "TestBeam"

        assert is_float(decoded_body["temperature"])
        assert is_float(decoded_body["top_p"])

        Req.Test.json(conn, %{
          "model" => "sonar-reasoning",
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
                  model: "sonar-reasoning",
                  tool_calls: nil,
                  tool_calls_results: nil
                }
              }} = Perplexity.call("test prompt", [beam], config)
    end
  end
end
