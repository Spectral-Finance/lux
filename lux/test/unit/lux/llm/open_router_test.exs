defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter

  defmodule SamplePrism do
    @moduledoc false
    use Lux.Prism,
      name: "Sample Prism",
      description: "A test prism for OpenRouter",
      input_schema: %{type: :object, properties: %{query: %{type: :string}}}

    def handler(input, _ctx), do: {:ok, input}
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3 and multi-model routing" do
    test "sends OpenRouter chat completion request and parses ResponseSignal with cost metadata" do
      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/chat/completions"

        {:ok, raw_body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(raw_body)
        assert decoded["model"] == "openai/gpt-4o-mini"
        assert decoded["models"] == ["openai/gpt-4o-mini", "anthropic/claude-3.5-sonnet"]

        Req.Test.json(conn, %{
          "id" => "gen-or-123",
          "model" => "openai/gpt-4o-mini",
          "created" => 1_710_000_000,
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "{\"summary\":\"Base liquidity is healthy\"}"
              }
            }
          ],
          "usage" => %{
            "prompt_tokens" => 1000,
            "completion_tokens" => 500
          }
        })
      end)

      Application.put_env(:lux, OpenRouter, plug: {Req.Test, OpenRouter})

      assert {:ok, signal} =
               OpenRouter.call(
                 "Check Base liquidity",
                 [SamplePrism.view()],
                 %{
                   model: "openai/gpt-4o-mini",
                   fallback_models: ["anthropic/claude-3.5-sonnet"],
                   api_key: "test-or-key"
                 }
               )

      assert signal.payload.content == %{"summary" => "Base liquidity is healthy"}
      assert signal.metadata.usage["estimated_cost_usd"] > 0.0
    end

    test "converts Prism tool into OpenRouter function definition" do
      fn_def = OpenRouter.tool_to_function(SamplePrism.view())
      assert fn_def.type == "function"
      assert fn_def.function.description == "A test prism for OpenRouter"
    end
  end
end
