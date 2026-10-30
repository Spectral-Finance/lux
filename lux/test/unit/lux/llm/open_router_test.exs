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
    test "converts a beam to an OpenRouter function" do
      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{type: "string", description: "Test value"}
            }
          }
        )

      function = OpenRouter.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "TestBeam",
                 description: "A test beam"
               }
             } = function
    end

    test "converts a prism to an OpenRouter function" do
      prism = TestPrism.view()

      function = OpenRouter.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OpenRouterTest_TestPrism",
                 description: "A test prism"
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes successful request and returns ResponseSignal" do
      config = %{
        api_key: "sk-or-test-key",
        model: "anthropic/claude-3.5-sonnet",
        temperature: 0.7
      }

      Req.Test.expect(OpenRouter, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer sk-or-test-key"]
        assert Plug.Conn.get_req_header(conn, "http-referer") == ["https://github.com/Spectral-Finance/lux"]
        assert Plug.Conn.get_req_header(conn, "x-title") == ["Lux Agent Framework"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["model"] == "anthropic/claude-3.5-sonnet"

        Req.Test.json(conn, %{
          "id" => "gen-12345",
          "model" => "anthropic/claude-3.5-sonnet",
          "created" => 1714800000,
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"analysis": "success"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 15,
            "completion_tokens" => 25,
            "total_tokens" => 40
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"analysis" => "success"},
                  finish_reason: "stop",
                  model: "anthropic/claude-3.5-sonnet"
                }
              }} = OpenRouter.call("test prompt", [], config)
    end

    test "handles tool calls with prism execution" do
      config = %{
        api_key: "sk-or-test-key",
        model: "openai/gpt-4o"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "gen-tool-123",
          "model" => "openai/gpt-4o",
          "choices" => [
            %{
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
              "finish_reason" => "tool_calls"
            }
          ]
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  finish_reason: "tool_calls",
                  model: "openai/gpt-4o",
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = OpenRouter.call("test tool call", [TestPrism], config)
    end

    test "handles authentication error 401" do
      config = %{api_key: "invalid-key"}

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, :invalid_api_key} = OpenRouter.call("test", [], config)
    end

    test "handles insufficient credits 402" do
      config = %{api_key: "empty-wallet"}

      Req.Test.expect(OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(402)
        |> Req.Test.json(%{"error" => %{"message" => "Insufficient credits"}})
      end)

      assert {:error, :insufficient_credits} = OpenRouter.call("test", [], config)
    end
  end
end
