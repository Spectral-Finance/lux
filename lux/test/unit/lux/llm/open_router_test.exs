defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
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
    test "converts a beam to an OpenRouter function" do
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

      function = OpenRouter.tool_to_function(beam)

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
    test "makes correct API call with tools and custom headers" do
      config = %{
        api_key: "test_key",
        model: "google/gemma-2-9b-it:free",
        app_url: "https://my-app.com",
        app_title: "My App"
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

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        referer_header = Plug.Conn.get_req_header(conn, "http-referer")
        assert ["https://my-app.com"] = referer_header

        title_header = Plug.Conn.get_req_header(conn, "x-title")
        assert ["My App"] = title_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "google/gemma-2-9b-it:free"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]

        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "TestBeam"

        Req.Test.json(conn, %{
          "model" => "google/gemma-2-9b-it:free",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "OpenRouter test response"})
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
                  content: %{"result" => "OpenRouter test response"},
                  finish_reason: "stop",
                  model: "google/gemma-2-9b-it:free",
                  tool_calls: nil,
                  tool_calls_results: nil
                }
              }} = OpenRouter.call("test prompt", [beam], config)
    end
  end
end
