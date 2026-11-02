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
    test "converts a beam to an OpenRouter function definition" do
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
    test "executes chat completion with model routing and cost tracking" do
      Req.Test.stub(Lux.LLM.OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/chat/completions"

        assert {"authorization", "Bearer test_openrouter_key"} in conn.req_headers
        assert {"http-referer", "https://github.com/Spectral-Finance/lux"} in conn.req_headers
        assert {"x-title", "Lux Framework"} in conn.req_headers

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "anthropic/claude-3.5-sonnet"
        assert decoded["models"] == ["openai/gpt-4o", "meta-llama/llama-3.3-70b-instruct"]
        assert decoded["route"] == "fallback"

        response = %{
          "id" => "gen-123456",
          "model" => "anthropic/claude-3.5-sonnet",
          "created" => 1_730_548_800,
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Hello from OpenRouter!"
              }
            }
          ],
          "usage" => %{
            "prompt_tokens" => 15,
            "completion_tokens" => 8,
            "total_tokens" => 23,
            "total_cost" => 0.00012
          }
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      config = %{
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        api_key: "test_openrouter_key",
        model: "anthropic/claude-3.5-sonnet",
        models: ["openai/gpt-4o", "meta-llama/llama-3.3-70b-instruct"],
        route: "fallback"
      }

      assert {:ok, %Signal{} = signal} = OpenRouter.call("Say hello", [], config)
      assert signal.payload.content == "Hello from OpenRouter!"
      assert signal.payload.model == "anthropic/claude-3.5-sonnet"
      assert signal.metadata.cost == 0.00012
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(Lux.LLM.OpenRouter, fn conn ->
        Plug.Conn.resp(conn, 401, Jason.encode!(%{"error" => %{"message" => "Invalid API Key"}}))
      end)

      config = %{
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        api_key: "bad_key"
      }

      assert {:error, :invalid_api_key} = OpenRouter.call("Test", [], config)
    end

    test "handles 429 rate limit" do
      Req.Test.stub(Lux.LLM.OpenRouter, fn conn ->
        Plug.Conn.resp(conn, 429, Jason.encode!(%{"error" => %{"message" => "Rate limit exceeded"}}))
      end)

      config = %{
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        api_key: "rate_limited_key"
      }

      assert {:error, :rate_limited} = OpenRouter.call("Test", [], config)
    end
  end
end
